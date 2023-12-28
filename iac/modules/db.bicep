@description('The name of the application')
param appName string

@description('Environment Name')
@allowed([
  'dev', 'tst', 'prd'
])
param environmentName string

@description('Location for all resources')
param location string

var accountName = 'cosmon-${appName}-${environmentName}-01'
var databaseName = 'db-${appName}-${environmentName}-01'
var serverVersion = '4.2'
var collection1Name = 'events'

resource account 'Microsoft.DocumentDB/databaseAccounts@2023-09-15' = {
  name: accountName
  location: location
  kind: 'MongoDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enableFreeTier: true
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    minimalTlsVersion: 'Tls12'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Eventual'
    }
    locations: [
      {
        locationName: location
      }
    ]
    apiProperties: {
      serverVersion: serverVersion
    }
    capabilities: [
      {
        name: 'DisableRateLimitingResponses'
      }
      {
        name: 'EnableMongoRoleBasedAccessControl'
      }
    ]
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2023-09-15' = {
  parent: account
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
    options: {}
  }
}

resource collection1 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2023-09-15' = {
  parent: database
  name: collection1Name
  properties: {
    resource: {
      id: collection1Name
      shardKey: {
        user_id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
      ]
    }
  }
}

output cosmosDbId string = account.id
output cosmosDbAccount string = account.name
output cosmosDbDatabaseName string = database.name
output cosmosDbCollectionName string = collection1.name
