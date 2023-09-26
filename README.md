# Azure Sample: Service Bus Queue Trigger Function App

## Prerequisites 
```
az group create --location canadacentral --name '{your resource group name}'

az ad sp create-for-rbac --name 'sp-github-dev' --role contributor --scopes /subscriptions/<your subscription id>/resourceGroups/<your resource group name> --json-auth

az role assignment create --assignee '<sp object id>' --role 'Role Based Access Control Administrator (Preview)' --scope 'subscriptions/<your subscription id>/resourceGroups/<your resource group name>'

az role assignment create --assignee '<user object id>' --role 'Azure Service Bus Data Receiver' --scope '/subscriptions/<your subscription id>/resourceGroups/<your resource group name>/providers/Microsoft.ServiceBus/namespaces/<service bus namespace>'

az role assignment create --assignee '<user object id>' --role 'Azure Service Bus Data Owner' --scope '/subscriptions/<your subscription id>/resourceGroups/<your resource group name>/providers/Microsoft.ServiceBus/namespaces/<service bus namespace>'
```