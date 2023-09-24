# azuresamples-servicebus-functionapp

```
az group create --location canadacentral --name '{your resource group name}'

az ad sp create-for-rbac --name 'sp-github-dev' --role contributor --scopes /subscriptions/{your subscription id}/resourceGroups/{your resource group name} --json-auth
```