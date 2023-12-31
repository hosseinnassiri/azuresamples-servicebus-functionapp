@description('The name of the application')
param appName string

@description('Environment Name')
@allowed([
  'dev', 'tst', 'prd'
])
param environmentName string

@description('Location for all resources')
param location string

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

@description('Application Id of API app')
param apiAppId string

@description('Application Id of Client app')
param clientAppId string

@description('Service Bus Namespace')
param serviceBus string

@description('Application Insights Instrumentation Key')
param appInsightsInstrumentationKey string

var apiManagementServiceName = 'apim-${appName}-${environmentName}-01'

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
  name: 'applicationinsights'
  parent: apiManagementService
  properties: {
    loggerType: 'applicationInsights'
    description: 'Logger resources to APIM'
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
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

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: serviceBus
}

resource serviceBusQueueSenderRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in serviceBusSenderRoles: {
  name: guid('sbns-apim-rbac', serviceBusNamespace.id, resourceGroup().id, apiManagementService.id, role.id)
  scope: serviceBusNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.id)
    principalId: apiManagementService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

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

resource apimApiAppNamedValues 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apiManagementService
  name: 'api-app-id'
  properties: {
    displayName: 'api-app-id'
    value: apiAppId
  }
}

resource apimClientAppNamedValues 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apiManagementService
  name: 'client-app-id'
  properties: {
    displayName: 'client-app-id'
    value: clientAppId
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: api
  properties: {
    format: 'rawxml'
    value: loadTextContent('../api-auth-policy-01.xml')
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
    value: loadTextContent('../sb-apim-policy-01.xml')
  }
  dependsOn: [
    apimSBEndpointNamedValues
  ]
}

resource pingApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  name: 'helloworld'
  parent: apiManagementService
  properties: {
    displayName: 'Hello World API'
    serviceUrl: 'http://localhost' // This is just a placeholder as we don't have a backend
    path: 'helloworld'
    protocols: [
      'https'
    ]
  }
}

resource pingApiOperation 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  name: 'hello'
  parent: pingApi
  properties: {
    displayName: 'Hello Operation'
    method: 'GET'
    urlTemplate: '/hello'
    request: {
      description: 'Hello Request'
    }
    responses: [
      {
        statusCode: 200
        description: 'OK'
        representations: [
          {
            contentType: 'application/json'
            examples: {
              default: {
                value: 'hello world!'
              }
            }
          }
        ]
      }
    ]
  }
}

output gatewayUrl string = apiManagementService.properties.gatewayUrl
// output apiIPAddress string = apiManagementService.properties.publicIPAddresses[0]  // no public ip for apim sku consumption
