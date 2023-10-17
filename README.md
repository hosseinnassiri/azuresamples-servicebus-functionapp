# Azure Service Bus Queue Trigger Function with System Assigned Managed Identity

The purpose of this repository is to demonstrate how to build a Azure Function App triggered by messages from an Azure Service Bus queue while utilizing a System Assigned Managed Identity for secure access to Azure resources. The Managed Identity eliminates the need for explicit credentials, enhancing the application's security and simplifying access management.

This hopefully serves as an educational resource and reference for developers and DevOps professionals looking to implement serverless Azure functions with managed identities and automate Azure infrastructure provisioning using Bicep and GitHub Actions for improved deployment efficiency and reliability.

![architecture diagram](docs/architecture.png)

## Key Features and Components
- **Azure API Management Service**
  - Azure APIM Operation Policies

- **Azure Function App**: Includes the Azure Functions runtime for executing your serverless functions.

- **Service Bus Queue Trigger**: Demonstrates how to set up a Function that triggers in response to messages arriving in an Azure Service Bus queue.

- **Azure App Configuration**

- **System Assigned Managed Identity**: Illustrates how to enable and configure a System Assigned Managed Identity for the Function App to securely access other Azure services.

- **Infrastructure as Code with Bicep**: Automates the deployment and provisioning of Azure resources using Bicep, a declarative language for Azure Resource Manager templates.

- **GitHub Actions**: Provides CI/CD automation for deploying the Azure infrastructure automatically whenever changes are pushed to the repository.

## Preparation

1- Create a resource group first:

```powershell
az group create --location canadacentral --name '<resource group name>'
```

2- Create a Service Principal to use for Github Action to create the infrastructure in Azure:

```powershell
az ad sp create-for-rbac --name 'sp-github-dev' --role contributor --scopes '/subscriptions/<subscription id>/resourceGroups/<resource group name>' --json-auth

az role assignment create --assignee '<sp object id>' --role 'Role Based Access Control Administrator (Preview)' --scope 'subscriptions/<subscription id>/resourceGroups/<resource group name>'
```

References:

- [Deploy Bicep files by using GitHub Actions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-github-actions?tabs=userlevel%2CCLI)
- [Use identity-based connections instead of secrets with triggers and bindings](https://learn.microsoft.com/en-us/azure/azure-functions/functions-identity-based-connections-tutorial-2)

3- Add required roles to your user to be able to develop locally:

```powershell
az role assignment create --assignee '<user object id>' --role 'Azure Service Bus Data Receiver' --scope '/subscriptions/<subscription id>/resourceGroups/<resource group name>/providers/Microsoft.ServiceBus/namespaces/<service bus namespace>'

az role assignment create --assignee '<user object id>' --role 'Azure Service Bus Data Owner' --scope '/subscriptions/<subscription id>/resourceGroups/<resource group name>/providers/Microsoft.ServiceBus/namespaces/<service bus namespace>'

az role assignment create --assignee '<user object id>' --role 'App Configuration Data Reader' --scope '/subscriptions/<subscription id>/resourceGroups/<resource group name>/providers/Microsoft.AppConfiguration/configurationStores/<app configuration name>'
```

4- Run the gihub action to create the Azure environment in your Azure subscription.

## Local development environment

Add the following to your **local.settings.json**:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "AppConfigConnection": "https://<app configuration name>.azconfig.io",
    "AppConfigConnection__clientId": "<user object id>",
    "ServiceBusConnection__fullyQualifiedNamespace": "<service bus namespace>.servicebus.windows.net",
    "ServiceBusConnection__clientId": "<user object id>",
    "ServiceBusQueue": "<queue name>",
    "AZURE_CLIENT_ID": "<user object id>",
    "AZURE_TENANT_ID": "<azure tenant id>"
  }
}
```

## Next steps

[ ] add authentication to apim api

[ ] add bicep modules
