@description('Environment Name')
@allowed([
  'dev', 'tst', 'prd'
])
param environmentName string

@description('Location for all resources')
param location string

var vnetName = 'vnet-${environmentName}-01'
var vnetAddressPrefixes = '10.0.0.0/16'

var privateEndpointSubnet = {
  name: 'snet-privatelinks-${environmentName}-01'
  properties: {
    addressPrefix: '10.0.0.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}
var appSubnet = {
  name: 'snet-app-${environmentName}-01'
  properties: {
    addressPrefix: '10.0.1.0/24'
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    delegations: [
      {
        name: 'webapp'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
}
var privateDnsZoneNames = [
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.table.${environment().suffixes.storage}'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.queue.${environment().suffixes.storage}'
]

resource dnsZoneNames 'Microsoft.Network/privateDnsZones@2020-06-01' = [for dnsZoneName in privateDnsZoneNames: {
  name: dnsZoneName
  location: 'global'
}]

resource vnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefixes
      ]
    }
    subnets: [
      privateEndpointSubnet
      appSubnet
    ]
  }
}
