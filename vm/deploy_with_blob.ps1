<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION

 .PARAMETER subscriptionId
    The subscription id where the template will be deployed.

 .PARAMETER resourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER resourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER deploymentName
    The deployment name.

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$subscriptionId = "69f423df-297f-4625-b184-1cd5027cdba8",

    [Parameter(Mandatory = $True)]
    [string]$resourceGroupName="moscow",
    
    [Parameter(Mandatory = $True)]
    [string]$resourceGroupForArtifactStorageName="london",
 
    [Parameter(Mandatory = $true)]
    [string]$resourceGroupLocation="westeurope",

    [Parameter(Mandatory = $false)]
    [string]$deploymentName = "Task 4 - Deploy ARM's",

    [string]$parametersFilePath = "s.json"
)
begin{
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    # Variables define
    $ARMGithubPrefix = "https://raw.githubusercontent.com/Nerwoolf/azure_arm/master/vm/"
    $DSCGithubPrefix ="https://github.com/Nerwoolf/azure_arm/raw/master/vm/iissettingup.ps1.zip"
    $FilesToDownload = [ordered]@{

                                    "azuredeploy" = "azuredeploy.json"
                                    "keyvault" = "keyvault.json"
                                    "virtnet" = "virtnet-with-pip.json"
                                    "vmdeploy" = "vmdeploy.json"
                                    "vmextension" = "vmextension.json"
                                    "storageaccout" = "storageaccount.json"
                                    "nsg" = "nsg.json"
                                    "deploy_with_blob" = "deploy_with_blob.ps1"
                                    
                                }
    $storAccName = ("stacc"+$resourceGroupName+01).ToLower()
    $storAccContainerName = ("automation{0}{1}" -f $resourceGroupForArtifactStorageName, $resourceGroupLocation)
    $tempDownloadFolder = "$env:USERPROFILE\desktop\temp"
    $resourceGroupName = $resourceGroupName.ToLower()
    $resourceGroupForArtifactStorageName = $resourceGroupForArtifactStorageName.ToLower()
    $ARMtemplateUri = ("https://{0}.blob.core.windows.net/{1}/" -f $storAccName, $storAccContainerName)
}
process {
    

    # sign in
    Write-host -ForegroundColor Green "Loging to azure subscription"
    $SubCheck = Get-AzureRmSubscription -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue
    if (!$SubCheck) {
        Connect-AzureRmAccount 
        Select-AzureRmContext -SubscriptionID $subscriptionId
    }

    #Create or check for existing resource group
    $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if (!$resourceGroup) {
        Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
        New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
    }
    else {
        Write-Host "Using existing resource group $resourceGroupName";
    }

    $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupForArtifactStorageName -ErrorAction SilentlyContinue
    if (!$resourceGroup) {
        Write-Host "Creating resource group '$resourceGroupForArtifactStorageName' in location '$resourceGroupLocation'";
        New-AzureRmResourceGroup -Name $resourceGroupForArtifactStorageName -Location $resourceGroupLocation
    }
    else {
        Write-Host "Using existing resource group $resourceGroupForArtifactStorageName";
    }

    # Create storage for artifatcs 
    New-AzureRmStorageAccount -ResourceGroupName $resourceGroupForArtifactStorageName -Location $resourceGroupLocation -Name $storAccName -SkuName Standard_LRS 
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroupForArtifactStorageName -Name $storAccName
    
    New-AzureStorageContainer -Name $storAccContainerName -Permission Off
    
    # Download files to container
    
    foreach ($item in $FilesToDownload.GetEnumerator()){
            $link = ("{0}{1}" -f $ARMGithubPrefix ,$item.value )
            New-Item -ItemType Directory -Path $tempDownloadFolder -ErrorAction SilentlyContinue 

            Invoke-WebRequest -Uri $link -OutFile "$tempDownloadFolder\$($item.value)"
    }
    Invoke-WebRequest -Uri $DSCGithubPrefix -OutFile "$tempDownloadFolder\iissettingup.ps1.zip"
    $files =  Get-ChildItem  -Path $tempDownloadFolder
    $files.FullName | ForEach-Object {Set-AzureStorageBlobContent -Container $storAccContainerName -force -File $_}
    
    # Create SAS token to storage account
    
    $sasToken = New-AzureStorageAccountSASToken -Service Blob -ResourceType Service, Container , Object -Permission "r" -Protocol HttpsOnly -ExpiryTime $(get-date).AddDays(2)
    
      

    # Start the deployment
    Write-Host "Starting deployment...";
    if (Test-Path $parametersFilePath) {
        New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateUri ($ARMtemplateUri+'azuredeploy.json'+$sasToken) -TemplateParameterFile $parametersFilePath -containerSASToken $sasToken -ARMlink $ARMtemplateUri
    }
    else {
        New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateUri ($ARMtemplateUri+'azuredeploy.json'+$sasToken) -containerSASToken $sasToken -ARMlink $ARMtemplateUri
    }
    Remove-Item -Path $tempDownloadFolder -Force
}