Param(  
	[string][Parameter(Mandatory)]$AppNamePrefix, # Prefix used for creating applications
	[string][Parameter()]$SendGridKey,
	[string][Parameter()]$SendGridFrom,
	[string][Parameter()]$TwilioSid,
	[string][Parameter()]$TwilioKey,
	[string][Parameter()]$TwilioPhoneNo,
	[string][Parameter()]$location = "canadaCentral", # Location of all resources
	[string][Parameter()]$subscriptionId # Id of Subscription to deploy to. If empty, defaults to the current account. Check 'az account show' to check.
) 

Write-Warning "Please ensure you are running azure CLI version 2.30+"

### Subscription Selection
if ($subscriptionId -ne ""){
	az account set -s $subscriptionId
}
else {
	$subscriptionId = az account show --query "id" --output tsv
}


#Variable setup
$resourceGroup = $AppNamePrefix
$storageName = ($AppNamePrefix + "storage") -replace "[^a-z0-9]",""
$functionAppName = "$AppNamePrefix-func" 
$keyVaultName = "$AppNamePrefix-kv"
$logAnalyticsWorkspace = "$AppNamePrefix-workspace"
$appInsightsName = "$AppNamePrefix-ai"
$serviceBusName = ($AppNamePrefix + "servicebus") -replace "[^a-z0-9]",""
$serviceBusEmailQueueName = "email"
$serviceBusSMSQueueName = "sms"

$keyVaultSendGridKeyName = "SendGrid--Key"
$keyVaultTwilioKeyName = "Twilio--Key"

###Resource Group creation
$rgExists = az group exists --name $resourceGroup 
if ($rgExists -eq 'false'){

	Write-Output "Resource Group '$resourceGroup' does not exist. Creating..."
	az group create `
		--name $resourceGroup `
		--location $location `
		--output none
	Write-Output "Resource Group '$resourceGroup' created"
}
else {
	Write-Output "Resource Group '$resourceGroup' already exists. Skipping..."
}

###Setting up Key Vault
$kvExists = az keyvault list --query "[?name=='$keyVaultName']" --output tsv
if ($null -eq $kvExists){
	Write-Host "KeyVault '$keyVaultName' does not exist. Creating..."
	az keyvault create `
		--resource-group $resourceGroup `
		--location $location `
		--name $keyVaultName `
		--output none
	Write-Output "Resource Group '$resourceGroup' created"
}
else {
	Write-Host "KeyVault '$keyVaultName' exists. Skipping..."
}

##Add Keys to vault
az keyvault secret set `
	--vault-name $keyVaultName `
	--name $keyVaultSendGridKeyName `
	--value $SendGridKey `
	--output none
az keyvault secret set `
	--vault-name $keyVaultName `
	--name $keyVaultTwilioKeyName `
	--value $TwilioKey `
	--output none

###Setting up Storage Account
$storageAvailable = az storage account check-name --name $storagename --query "nameAvailable"
if ($storageAvailable -eq $true){
	Write-Output "Storage Account '$storagename' does not exist. Creating..."
	az storage account create `
		--resource-group $resourceGroup `
		--location $location `
		--name $storagename `
		--sku Standard_LRS `
		--output tsv
	Write-Output "Storage Account '$storagename' created"
	
	$storageConnectionString = az storage account show-connection-string `
		--resource-group $resourceGroup `
		--name $storagename `
		--output tsv

	az keyvault secret set `
		--vault-name $keyVaultName `
		--name 'Storage--ConnectionString' `
		--value $storageConnectionString `
		--output none
}
else {
	Write-Output "Storage Account '$storagename' already exists. Skipping..."
}

##Application Insights
Write-Host "Creating App Insights '$appInsightsName'..."	

az monitor log-analytics workspace create `
	--resource-group $resourceGroup `
	--workspace-name $logAnalyticsWorkspace `
	--output none

$appInsightsKey = az monitor app-insights component create `
		--resource-group $resourceGroup `
		--app $appInsightsName `
		--location $location `
		--workspace $logAnalyticsWorkspace `
		--kind web `
		--application-type web `
		--query "{ik:instrumentationKey}" `
		--output tsv

Write-Output "App Insights '$appInsightsName' created"


#setting up Service Bus
$serviceBusExists = !(az servicebus namespace exists --name $serviceBusName --query "{n:nameAvailable}" --output tsv)
if ($serviceBusExists -eq $false) {
	Write-Host "Service Bus namespace '$serviceBusName' does not exist. Creating..."

	az servicebus namespace create `
		--resource-group $resourceGroup `
		--location $location `
		--name $serviceBusName `
		--sku Standard `
		--output none
	Write-Host "Service Bus namespace '$serviceBusName' created."
}
else {
	Write-Host "Service Bus namespace '$serviceBusName' exists. Skipping..."
}

$serviceBusId = `
  az servicebus namespace show `
	  --resource-group $resourceGroup `
	  --name $serviceBusName `
	  --query "{id:id}" `
	  --output tsv


#Setting up Service Bus Queues
az servicebus queue create `
	--resource-group $resourceGroup `
	--namespace-name $serviceBusName `
	--name $serviceBusEmailQueueName `
	--output none

	
#Setting up Service Bus Queues
az servicebus queue create `
	--resource-group $resourceGroup `
	--namespace-name $serviceBusName `
	--name $serviceBusSMSQueueName `
	--output none

	
Write-Host "-> Creating Azure Functions '$functionAppName'"	
az functionapp create `
	--resource-group $resourceGroup `
	--name $functionAppName `
	--consumption-plan-location $location `
	--storage-account $storageName `
	--assign-identity `
	--functions-version 4 `
	--os-type Windows `
	--runtime dotnet `
	--app-insights $appInsightsName `
	--app-insights-key $appInsightsKey `
	--output none

$functionIdentity = 
	az webapp identity show `
		--resource-group $resourceGroup `
		--name $functionAppName `
		--query "{id:principalId}" `
		--output tsv

#add a cors rule so we can run from portal
az functionapp cors add `
	--resource-group $resourceGroup `
	--name $functionAppName `
	--allowed-origins https://ms.portal.azure.com  `
	--output none

#assign function reader role to the Service bus 
#Azure Service Bus Data Receiver
az role assignment create `
    --assignee $functionIdentity `
    --role "4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0" `
    --scope $serviceBusId `
	--output none

#Azure Service Bus Data Sender
az role assignment create `
    --assignee $functionIdentity `
    --role "69a216fc-b8fb-44d8-bc22-1f3c2cd27a39" `
    --scope $serviceBusId `
	--output none


#weird bug in PowerShell, need to use this method otherwise the ) will not be added to the setting 
$SendGridKeyValue='"@Microsoft.KeyVault(VaultName={0};SecretName={1})"' -f $keyVaultName, $keyVaultSendGridKeyName
$TwilioKeyValue='"@Microsoft.KeyVault(VaultName={0};SecretName={1})"' -f $keyVaultName, $keyVaultTwilioKeyName
		
az functionapp config appsettings set `
	--resource-group $resourceGroup `
	--name $functionAppName `
	--settings ServiceBus__fullyQualifiedNamespace="$serviceBusName.servicebus.windows.net" `
			   ServiceBus__credential="managedidentity" `
			   ServiceBus-EmailQueue=$serviceBusEmailQueueName `
			   ServiceBus-SMSQueue=$serviceBusSMSQueueName `
			   SendGrid-Key=$SendGridKeyValue `
			   SendGrid-From=$SendGridFrom `
			   Twilio-SID=$TwilioSid `
			   Twilio-Key=$TwilioKeyValue `
			   Twilio-PhoneNo=$TwilioPhoneNo `
			   WEBSITE_RUN_FROM_PACKAGE=1 `
	--output none

Write-Host "-> Set KeyVault Access policy for function app"	
az keyvault set-policy `
	--resource-group $resourceGroup `
	--name $keyVaultName `
	--object-id $functionIdentity `
	--secret-permissions get list `
	--output none

Write-Host "Azure Functions '$functionAppName' created."	
