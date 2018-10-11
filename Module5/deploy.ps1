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
 
    [Parameter(Mandatory = $true)]
    [string]$resourceGroupLocation="northeurope",

    [Parameter(Mandatory = $true)]
    [string]$SecondtWebAppLocation="westeurope",

    [Parameter(Mandatory = $false)]
    [string]$deploymentName = "Task 5 - Deploy WebApp",

    [Parameter(Mandatory = $false)]
    [string]$uniqueDnsName= "azure-lab5",
    
    [Parameter(Mandatory = $false)]
    [string]$ARMtemplateUri = "https://raw.githubusercontent.com/Nerwoolf/azure_arm/master/Module5/azuredeploy.json",

    [Parameter(Mandatory = $false)]
    [string]$parametersFilePath = "s.json",

    [Parameter(Mandatory = $false)]
    [String]$fileUri= "https://raw.githubusercontent.com/Nerwoolf/azure_arm/master/Module5/page/index.html",

    [Parameter(Mandatory = $false)]
    $appdirectory = "$env:USERPROFILE\desktop\tempsite"
)
begin{
     # sign in
     Write-host -ForegroundColor Green "Loging to azure subscription"
     $SubCheck = Get-AzureRmSubscription -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue
     if (!$SubCheck) {
         Connect-AzureRmAccount 
         Select-AzureRmContext -SubscriptionID $subscriptionId
     }
 
     # Create or check for existing resource group
     $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
     if (!$resourceGroup) {
         Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
         New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
     }
     else {
         Write-Host "Using existing resource group $resourceGroupName";
     }



}
process{
    # Start the deployment
    Write-Host "Starting deployment...";
    if (Test-Path $parametersFilePath) {
        New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateUri $ARMtemplateUri -TemplateParameterFile $parametersFilePath -ResourceGroupLocation $resourceGroupLocation -SecondWebAppLocation $SecondtWebAppLocation -Mode Complete -AsJob -Force
    }
    else {
        New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateUri $ARMtemplateUri -SecondWebAppLocation $SecondtWebAppLocation -ResourceGroupLocation $resourceGroupLocation  -Mode Complete -AsJob -Force
    }

    # Wait for ARM Deploy
    Write-host -ForegroundColor Yellow "Waiting for deploy job complete..."
    get-job | wait-job
    $webappname = Get-AzureRmWebApp -ResourceGroupName $resourceGroupName | Select-Object -First 1

    # Get publishing profile for the web app
    new-item -ItemType Directory -Path $appdirectory -ErrorAction SilentlyContinue
    $xml = [xml](Get-AzureRmWebAppPublishingProfile -Name $webappname.Name -ResourceGroupName $resourceGroupName -OutputFile "$appdirectory\null")

    # Extract connection information from publishing profile
    $username = $xml.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@userName").value
    $password = $xml.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@userPWD").value
    $url = $xml.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@publishUrl").value

    # Download index.html to temp folder
    
    Invoke-WebRequest -Uri $fileUri -OutFile "$appdirectory\index.html"

    # Upload files recursively 
    Set-Location $appdirectory
    $webclient = New-Object -TypeName System.Net.WebClient
    $webclient.Credentials = New-Object System.Net.NetworkCredential($username,$password)
    $files = Get-ChildItem -Path $appdirectory -Recurse | Where-Object{!($_.PSIsContainer)}
    foreach ($file in $files)
    {
        $relativepath = (Resolve-Path -Path $file.FullName -Relative).Replace(".\", "").Replace('\', '/')
        $uri = New-Object System.Uri("$url/$relativepath")
        "Uploading to " + $uri.AbsoluteUri
        $webclient.UploadFile($uri, $file.FullName)
    } 
    $webclient.Dispose()

}
end{
    $url = $(Get-AzureRmTrafficManagerProfile -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue).RelativeDnsName
    if($url){
        Write-host -ForegroundColor Green ("Your traffic manager dns name is `t http://{0}.trafficmanager.net" -f $url)
    } else {
        Write-host "Some Error was got"
        $Error
    }
}