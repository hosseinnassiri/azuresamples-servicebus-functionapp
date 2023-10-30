@description('The name of the application')
param appName string

@description('Environment Name')
@allowed([
  'dev', 'tst', 'prd'
])
param environmentName string

@description('Location for all resources')
param location string

var serviceBusNamespaceName = 'sbns-${appName}-${environmentName}-01'
var serviceBusQueueName = 'sbq-${appName}-${environmentName}-01'
var serviceBusQueueAuthRule = 'sbqauth-${appName}-${environmentName}'

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

output serviceBusHostName string = '${serviceBusNamespace.name}.servicebus.windows.net'
output serviceBusQueue string = serviceBusQueue.name
output serviceBus string = serviceBusNamespace.name
