# Azure Service Bus Queue Trigger Function App

## Prerequisites
1- Create a resource group first:
``` powershell
az group create --location canadacentral --name '<resource group name>'
```

2- Create a Service Principal to use for Github Action to create the infrastructure in Azure:
``` powershell
az ad sp create-for-rbac --name 'sp-github-dev' --role contributor --scopes '/subscriptions/<subscription id>/resourceGroups/<resource group name>' --json-auth

az role assignment create --assignee '<sp object id>' --role 'Role Based Access Control Administrator (Preview)' --scope 'subscriptions/<subscription id>/resourceGroups/<resource group name>'
```

3- Add required roles to your user to be able to develop locally:
``` powershell
az role assignment create --assignee '<user object id>' --role 'Azure Service Bus Data Receiver' --scope '/subscriptions/<subscription id>/resourceGroups/<resource group name>/providers/Microsoft.ServiceBus/namespaces/<service bus namespace>'

az role assignment create --assignee '<user object id>' --role 'Azure Service Bus Data Owner' --scope '/subscriptions/<subscription id>/resourceGroups/<resource group name>/providers/Microsoft.ServiceBus/namespaces/<service bus namespace>'
```

## Local development environment
Add the following to your **local.settings.json**:
``` json
{
	"IsEncrypted": false,
	"Values": {
		"AzureWebJobsStorage": "UseDevelopmentStorage=true",
		"FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
		"ServiceBusConnection__fullyQualifiedNamespace": "<service bus namespace>.servicebus.windows.net",
		"ServiceBusConnection__clientId": "<user object id>",
		"ServiceBusQueue": "<queue name>",
		"AZURE_CLIENT_ID": "<user object id>",
		"AZURE_TENANT_ID": "<azure tenant id>"
	}
}

```