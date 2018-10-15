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

    [Parameter(Mandatory = $false)]
    [string]$deploymentName = "Task 7 - Backup",
    
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultUri= "https://raw.githubusercontent.com/Nerwoolf/azure_arm/test/keyvault.json",

    [Parameter(Mandatory = $false)]
    [string]$parametersFilePath = "s.json"
)
begin{
     # Password
     $passwordVM = Read-Host -Prompt "Please input password for VM" -AsSecureString
  
     # sign in
     Write-host -ForegroundColor Green "Loging to azure subscription"
     $SubCheck = Get-AzureRmSubscription -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue
     if (!$SubCheck) {
         Connect-AzureRmAccount 
         set-AzureRmContext -SubscriptionID $subscriptionId
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
    Write-Host "Start deploying keyvault"
    New-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateUri $KeyVaultUri -secretsObject $passwordVM -Verbose

}
 




