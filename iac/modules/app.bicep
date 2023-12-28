@description('The name of the application')
param appName string

@description('Environment Name')
@allowed([
  'dev', 'tst', 'prd'
])
param environmentName string

@description('Location for all resources')
param location string

@description('Storage Account type')
@allowed([
  'Standard_LRS'
])
param storageAccountType string

@description('Specifies the OS used for the Azure Function hosting plan.')
@allowed([
  'Windows'
  'Linux'
])
param functionPlanOS string = 'Windows'

@description('Service Bus Namespace')
param serviceBus string

@description('Host name of the service bus')
param serviceBusHostName string

@description('Service bus queue name')
param serviceBusQueueName string

@description('Application Insights connection string')
param applicationInsightsConnectionString string

@description('Cosmos DB Account name')
param cosmosDbAccountName string

@description('Cosmos DB Database name')
param cosmosDbDatabaseName string

@description('Cosmos DB Database name')
param cosmosDbContainerName string

var storageAccountName = 'stfunc${uniqueString(resourceGroup().id)}'
var outputStorageAccountName = 'stoutput${uniqueString(resourceGroup().id)}'
var hostingPlanName = 'asp-${appName}-${environmentName}-01'
var functionAppName = 'func-${appName}-${environmentName}-01'
var functionWorkerRuntime = 'dotnet-isolated'
var functionDotnetVersion = 'v8.0'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: hostingPlanName
  location: location
  kind: functionPlanOS
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      netFrameworkVersion: functionDotnetVersion
      use32BitWorkerProcess: false
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'ServiceBusConnection__fullyQualifiedNamespace'
          value: serviceBusHostName
        }
        {
          name: 'ServiceBusQueue'
          value: serviceBusQueueName
        }
        {
          name: 'AppConfigConnection'
          value: appConfig.properties.endpoint
        }
        {
          name: 'ArchiveBlobConnection__blobServiceUri'
          value: archiveStorageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'CosmosDBConnection__accountEndpoint'
          value: cosmosDbAccount.properties.documentEndpoint
        }
        {
          name: 'CosmosDbDatabase'
          value: cosmosDbDatabaseName
        }
        {
          name: 'CosmosDbContainer'
          value: cosmosDbContainerName
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

var storageRoles = [
  {
    name: 'Storage Blob Data Owner'
    id: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  }
  {
    name: 'Storage Account Contributor'
    id: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  }
]

resource storageRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in storageRoles: {
  name: guid('st-func-rbac', storageAccount.id, resourceGroup().id, functionApp.id, role.id)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

var appConfigName = 'appcs-${appName}-${environmentName}-01'

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: appConfigName
  location: location
  sku: {
    name: 'free'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

var keyValueNames = [
  'myKey'
  'myKey$myLabel'
]

var keyValueValues = [
  'Key-value without label'
  'Key-value with label'
]

resource configStoreKeyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = [for (item, i) in keyValueNames: {
  parent: appConfig
  name: item
  properties: {
    value: keyValueValues[i]
    contentType: 'string'
  }
}]

var appConfigRoles = [
  {
    name: 'App Configuration Data Reader'
    id: '516239f1-63e1-4d78-a4de-a74fb236a071'
  }
]

resource appConfigRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in appConfigRoles: {
  name: guid('appcs-func-rbac', appConfig.id, resourceGroup().id, functionApp.id, role.id)
  scope: appConfig
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: serviceBus
}

var serviceBusRoles = [
  {
    name: 'Azure Service Bus Data Receiver'
    id: '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
  }
  {
    name: 'Azure Service Bus Data Owner'
    id: '090c5cfd-751d-490a-894a-3ce6f1109419'
  }
]

resource serviceBusFuncRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in serviceBusRoles: {
  name: guid('sbns-func-rbac', serviceBusNamespace.id, resourceGroup().id, functionApp.id, role.id)
  scope: serviceBusNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

resource archiveStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: outputStorageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
  }
}

resource outputStorageRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in storageRoles: {
  name: guid('st-func-rbac', archiveStorageAccount.id, resourceGroup().id, functionApp.id, role.id)
  scope: archiveStorageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-09-15' existing = {
  name: cosmosDbAccountName
}

var cosmosDbRoles = [
  {
    name: 'DocumentDB Account Contributor'
    id: '5bd9cd88-fe45-4216-938b-f97437e15450'
  }
]

resource cosmosDbFuncRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in cosmosDbRoles: {
  name: guid('sbns-func-rbac', cosmosDbAccount.id, resourceGroup().id, functionApp.id, role.id)
  scope: cosmosDbAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

output functionAppName string = functionApp.name
output functionAppId string = functionApp.id
output functionAppPrincipalId string = functionApp.identity.principalId
output appConfigEndpoint string = appConfig.properties.endpoint
