@description('The name of app config')
param appConfigName string

@description('ping api url')
param pingApiUrl string

@description('azure ad authentication scope')
param authenticationScope string

var keyValueNames = [
  'settings:pingApiUrl'
  'settings:authenticationScope'
]

var keyValueValues = [
  pingApiUrl
  authenticationScope
]

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2024-05-01' existing = {
  name: appConfigName
}

resource configStoreKeyValue 'Microsoft.AppConfiguration/configurationStores/keyValues@2024-05-01' = [for (item, i) in keyValueNames: {
  parent: appConfig
  name: item
  properties: {
    value: keyValueValues[i]
    contentType: 'string'
  }
}]
