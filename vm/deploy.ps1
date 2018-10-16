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
 [Parameter(Mandatory=$false)]
 [string]$subscriptionId = "69f423df-297f-4625-b184-1cd5027cdba8",

 [Parameter(Mandatory=$True)]
 [string]$resourceGroupName,
 
 [Parameter(Mandatory=$true)]
 [string]$resourceGroupLocation,

 [Parameter(Mandatory=$false)]
 [string]$deploymentName="Task 4 - Deploy ARM's",

 [string]$templateUri = "https://raw.githubusercontent.com/Nerwoolf/azure_arm/module7/vm/azuredeploy.json",

 [string]$armLink = "https://raw.githubusercontent.com/Nerwoolf/azure_arm/module7/vm/",

 [string]$parametersFilePath = "s.json"
)
begin{
    $resourceGroupName = $resourceGroupName.ToLower()
    # Password for KeyVault
    $password = @{
            "secrets"=@(
                @{
                    "secretname"="vm"
                    "secretvalue"="$(read-host -Prompt "Please input password for VM" -AsSecureString)"
                }
                <#,
                @{
                    "secretname"="SQL"
                    "secretValue"="aaasdkasd"
                }
                #>
            )
    }

    # sign in
    Write-host -ForegroundColor Green "Loging to azure subscription"
    $SubCheck = Get-AzureRmSubscription -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue
    if(!$SubCheck){
        Connect-AzureRmAccount 
        Set-AzureRmContext -SubscriptionID $subscriptionId
    } else {
        Set-AzureRmcontext -SubscriptionId $subscriptionId
    }

    #Create or check for existing resource group
    $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if(!$resourceGroup)
    {
        Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
        New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
    }
    else{
        Write-Host "Using existing resource group $resourceGroupName";
    }
}
process{
        
        # Start the deployment
    Write-Host "Starting deployment..."
    if(Test-Path $parametersFilePath) {
        New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateUri $templateUri -TemplateParameterFile $parametersFilePath
    } else {
        New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateUri $templateUri -secretsObject $password -armLink $armLink
    }

    # Wait minute for backup agent
    Write-host -ForegroundColor Yellow "Waiting for backup agent provision be complete"

    # Trigger backup 
    $backupVault = Get-AzureRmRecoveryServicesVault -ResourceGroupName $resourceGroupName
    $backupVault | Set-AzureRmRecoveryServicesVaultContext
    
    # Starting backup job
    $namedContainer = Get-AzureRmRecoveryServicesBackupContainer -ContainerType "AzureVM" 
    $item = Get-AzureRmRecoveryServicesBackupItem -Container $namedContainer -WorkloadType "AzureVM"
    $job = Backup-AzureRmRecoveryServicesBackupItem -Item $item

    # Wait for backup job complete
    Write-host -ForegroundColor Yellow "waiting for backup" 
    do {
       $progress = Get-AzureRmRecoveryservicesBackupJob –Status "InProgress"
       Write-host -NoNewline "." 
       Start-Sleep -Seconds 10
    } while ($progress)
    
    # Get recovery points
    
    $backupitem = Get-AzureRmRecoveryServicesBackupItem -Container $namedContainer  -WorkloadType "AzureVM"
    $recoveryPoint = Get-AzureRmRecoveryServicesBackupRecoveryPoint -Item $backupitem
    
    # Create RG to restore
    $recoveryRgName = "recovery-group-module7"
    $recoveryRg = New-AzureRmResourceGroup -Name $recoveryRgName -Location $resourceGroupLocation
    
    # Create Storage account in recovery RG
    $storaccount = New-AzureRmStorageAccount -Name "module7recoverystor" -ResourceGroupName $recoveryRgName -Location $resourceGroupLocation -SkuName Standard_LRS -Kind StorageV2
    
    # Start recovery from last recovery point
    Write-host -ForegroundColor Yellow "Starting recovery to another RG and storage account"
    $restorejob = Restore-AzureRmRecoveryServicesBackupItem -RecoveryPoint $recoveryPoint[0] `
                                                            -StorageAccountName $storaccount.StorageAccountName `
                                                            -StorageAccountResourceGroupName "$recoveryRgName"
    Start-Sleep 2
    Write-Host -ForegroundColor Yellow "Now waiting for recovery job complete"
    Wait-AzureRmRecoveryServicesBackupJob -Job $restorejob -Timeout 43200
    
    # Get blob url from storage account
    $recoveryAccContainer = Get-AzureStorageContainer -Context $storaccount.Context
    $recoveryAccBlob = Get-AzureStorageBlob -Context $storaccount.Context -Container $recoveryAccContainer.Name | Where-Object -Property Length -ge 1GB


}