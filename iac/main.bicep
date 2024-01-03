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

@description('Location for all resources')
param location string = resourceGroup().location

@description('Specifies the OS used for the Azure Function hosting plan.')
@allowed([
  'Windows'
  'Linux'
])
param functionPlanOS string = 'Windows'

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

module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    appName: appName
    location: location
    environmentName: environmentName
  }
}

module integration './modules/integration.bicep' = {
  name: 'integration'
  params: {
    appName: appName
    location: location
    environmentName: environmentName
  }
}

module function './modules/app.bicep' = {
  name: 'app'
  params: {
    appName: appName
    location: location
    environmentName: environmentName
    applicationInsightsConnectionString: monitoring.outputs.connectionString
    serviceBusHostName: integration.outputs.serviceBusHostName
    serviceBusQueueName: integration.outputs.serviceBusQueue
    serviceBus: integration.outputs.serviceBus
    storageAccountType: storageAccountType
    functionPlanOS: functionPlanOS
    cosmosDbAccountName: db.outputs.cosmosDbAccount
    cosmosDbDatabaseName: db.outputs.cosmosDbDatabaseName
    cosmosDbContainerName: db.outputs.cosmosDbCollectionName
  }
}

module apim './modules/apim.bicep' = {
  name: 'api'
  params: {
    appName: appName
    location: location
    environmentName: environmentName
    appInsightsInstrumentationKey: monitoring.outputs.instrumentationKey
    apimSku: apimSku
    serviceBus: integration.outputs.serviceBus
    apiAppId: apiAppId
    clientAppId: clientAppId
    functionAppClientId: function.outputs.functionAppClientId
  }
}

module db './modules/db.bicep' = {
  name: 'db'
  params: {
    appName: appName
    location: location
    environmentName: environmentName
  }
}

output functionAppName string = function.outputs.functionAppName
output appConfigurationEndpoint string = function.outputs.appConfigEndpoint
