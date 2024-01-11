// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/privatednszones?pivots=deployment-language-bicep

@description('The Private DNS zones that will be deployed.')
param privateDnsZoneNames array

@description('Tags that will be added on the deployed resources.')
param tags object = {}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = [for (zone, i) in privateDnsZoneNames: {
  name: zone
  location: 'global'
  tags: tags
}]

resource privateDnsZoneSoa 'Microsoft.Network/privateDnsZones/SOA@2020-06-01' existing = [for (zone, i) in privateDnsZoneNames: {
  name: '@'
  parent: privateDnsZone[i]
}]

resource privateDnsZoneSoaLock 'Microsoft.Authorization/locks@2020-05-01' = [for (zone, i) in privateDnsZoneNames: {
  name: 'CanNotDeleteLock'
  scope: privateDnsZoneSoa[i]
  properties: {
    level: 'CanNotDelete'
  }
}]

// Outputs
output privateDnsZoneIds array = [for (zone, i) in privateDnsZoneNames: privateDnsZone[i].id ]
