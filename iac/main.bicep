@description('The name of the application')
param appName string = 'sample'

@description('Environment Name')
@allowed([
  'dev', 'tst', 'prd'
])
param environmentName string = 'dev'

@description('Storage Account type')
@allowed([
  'Standard_LRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Specifies the OS used for the Azure Function hosting plan.')
@allowed([
  'Windows'
  'Linux'
])
param functionPlanOS string = 'Windows'

var serviceBusNamespaceName = 'sbns-${appName}-${environmentName}-01'
var serviceBusQueueName = 'sbq-${appName}-${environmentName}-01'
var serviceBusQueueAuthRule = 'sbqauth-${appName}-${environmentName}'
var functionAppName = 'func-${appName}-${environmentName}-01'
var hostingPlanName = 'asp-${appName}-${environmentName}-01'
var logAnalyticsWorkspaceName = 'log-${appName}-${environmentName}-01'
var applicationInsightsName = 'appi-${appName}-${environmentName}-01'
var storageAccountName = 'stfunc${uniqueString(resourceGroup().id)}'
var functionWorkerRuntime = 'dotnet-isolated'
var functionDotnetVersion = 'v7.0'
var appConfigName = 'appcs-${appName}-${environmentName}-01'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    minimumTlsVersion: '1.2'
  }
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: serviceBusQueueName
  properties: {}
}

resource ruleListen 'Microsoft.ServiceBus/namespaces/queues/authorizationRules@2022-10-01-preview' = {
  name: serviceBusQueueAuthRule
  parent: serviceBusQueue
  properties: {
    rights: [
      'Listen'
    ]
  }
}

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
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'ServiceBusConnection__fullyQualifiedNamespace'
          value: '${serviceBusNamespaceName}.servicebus.windows.net'
        }
        {
          name: 'ServiceBusQueue'
          value: serviceBusQueueName
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

var roles = [
  {
    name: 'Azure Service Bus Data Receiver'
    id: '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
  }
  {
    name: 'Azure Service Bus Data Owner'
    id: '090c5cfd-751d-490a-894a-3ce6f1109419'
  }
]

resource serviceBusQueueRoles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in roles: {
  name: guid('sbns-rbac', serviceBusNamespace.id, resourceGroup().id, functionApp.id, role.id)
  scope: serviceBusNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2021-10-01-preview' = {
  name: appConfigName
  location: location
  sku: {
    name: 'free'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output functionAppName string = functionApp.name
