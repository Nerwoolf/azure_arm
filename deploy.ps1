param(
	[Parameter(Mandatory=$true)]
	[Sting]$ResoursGroupName,
	
	[Parameter(Mandatory=$true)]
	[String]$Location,
	
	[Parameter(Mandatory=$false)]
	[String]$SubscriptionId = "69f423df-297f-4625-b184-1cd5027cdba8"
)
try{
	set-azurermcontext 
} catch{
	
}
Connect-AzureRmAccount
dfa9d12f-387e-4391-8f5e-dd3e269367ea