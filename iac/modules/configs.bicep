@description('The name of the application')
param appName string

@description('Environment Name')
@allowed([
  'dev', 'tst', 'prd'
])
param environmentName string

@description('Location for all resources')
param location string

@description('ping api url')
param pingApiUrl string

@description('azure ad authentication scope')
param authenticationScope string

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
  'pingApiUrl'
  'authenticationScope'
]

var keyValueValues = [
  pingApiUrl
  authenticationScope
]

resource configStoreKeyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = [for (item, i) in keyValueNames: {
  parent: appConfig
  name: item
  properties: {
    value: keyValueValues[i]
    contentType: 'string'
  }
}]

output appConfigName string = appConfig.name
