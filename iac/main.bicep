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
          value: '${serviceBusNamespace.name}.servicebus.windows.net'
        }
        {
          name: 'ServiceBusQueue'
          value: serviceBusQueueName
        }
        {
          name: 'AppConfigConnection'
          value: appConfig.properties.endpoint
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

var apiManagementServiceName = 'apim-${appName}-${environmentName}-01'

@description('The email address of the owner of the service')
@minLength(1)
param publisherEmail string = 'hossein.nassiri@gmail.com'

@description('The name of the owner of the service')
@minLength(1)
param publisherName string = 'Hossein'

@description('The pricing tier of this API Management service')
@allowed([
  'Consumption' // for consumption capacity should be set az 0
  'Developer'
])
param apimSku string = 'Consumption'

resource apiManagementService 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: apimSku
    capacity: 0
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

resource apiManagementLogger 'Microsoft.ApiManagement/service/loggers@2023-03-01-preview' = {
  name: applicationInsights.name
  parent: apiManagementService
  properties: {
    loggerType: 'applicationInsights'
    description: 'Logger resources to APIM'
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
  }
}

resource apimInstanceDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2023-03-01-preview' = {
  name: 'applicationinsights'
  parent: apiManagementService
  properties: {
    loggerId: apiManagementLogger.id
    alwaysLog: 'allErrors'
    logClientIp: true
    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }
  }
}

var serviceBusSenderRoles = [
  {
    name: 'Azure Service Bus Data Sender'
    id: '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
  }
]

resource serviceBusQueueSenderRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in serviceBusSenderRoles: {
  name: guid('sbns-apim-rbac', serviceBusNamespace.id, resourceGroup().id, apiManagementService.id, role.id)
  scope: serviceBusNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: apiManagementService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

output gatewayUrl string = apiManagementService.properties.gatewayUrl
// output apiIPAddress string = apiManagementService.properties.publicIPAddresses[0]  // no public ip for apim sku consumption

resource api 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  name: 'service-bus-operations'
  parent: apiManagementService
  properties: {
    displayName: 'Service Bus Operations'
    path: 'sb-operations'
    apiType: 'http'
    protocols: [
      'https'
    ]
    subscriptionRequired: true
  }
}

resource apimTenantIdNamedValues 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apiManagementService
  name: 'tenant-id'
  properties: {
    displayName: 'tenant-id'
    value: tenant().tenantId
  }
}

param utcValue string = utcNow()

var managedIdentityName = 'uid-${appName}-${environmentName}-01'

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

@description('The resource ID of the user-assigned managed identity.')
output managedIdentityResourceId string = userAssignedIdentity.id

var userAssignedManagedIdentityRoles = [
  {
    name: 'Application Administrator'
    id: '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3'
  }
]

resource apiApp 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'azcli-api-app-registration'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.37.0'
    timeout: 'PT30M'
    arguments: '\'foo\' \'bar\''
    environmentVariables: [
      {
        name: 'UserName'
        value: 'jdole'
      }
    ]
    scriptContent: 'az rest --method POST --uri https://graph.microsoft.com/beta/roleManagement/directory/roleAssignments --body "{"principalId": "${userAssignedIdentity.id}", "roleDefinitionId": "${userAssignedManagedIdentityRoles[0].id}"}" > $AZ_SCRIPTS_OUTPUT_PATH'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

resource apimApiAppNamedValues 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apiManagementService
  name: 'api-app-id'
  properties: {
    displayName: 'api-app-id'
    value: ''
  }
}

resource apimClientAppNamedValues 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apiManagementService
  name: 'client-app-id'
  properties: {
    displayName: 'client-app-id'
    value: ''
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'rawxml'
    value: loadTextContent('api-auth-policy-01.xml')
  }
}

resource apiOperation 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  name: 'send-message'
  parent: api
  properties: {
    displayName: 'Send Message'
    method: 'POST'
    urlTemplate: '/{queue_or_topic}'
    templateParameters: [
      {
        name: 'queue_or_topic'
        type: 'string'
      }
    ]
  }
}

resource apimSBEndpointNamedValues 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apiManagementService
  name: 'service-bus-endpoint'
  properties: {
    displayName: 'service-bus-endpoint'
    value: serviceBusNamespace.properties.serviceBusEndpoint
  }
}

resource serviceBusOperationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: apiOperation
  properties: {
    format: 'rawxml'
    value: loadTextContent('sb-apim-policy-01.xml')
  }
  dependsOn: [
    apimSBEndpointNamedValues
  ]
}

output functionAppName string = functionApp.name
output appConfigurationEndpoint string = appConfig.properties.endpoint
