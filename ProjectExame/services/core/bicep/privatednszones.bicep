// Parameters
@description('Regioncode for the deployed resources.')
param regionCode string

// Variables
var privateDnsZoneNames =[
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.table.${environment().suffixes.storage}'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.${regionCode}.backup.windowsazure.com'
  'privatelink.azurewebsites.net'
  'scm.privatelink.azurewebsites.net'
  'privatelink.vaultcore.azure.net'
]

// Private DNS Zones
resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zone in privateDnsZoneNames: {
  name: zone 
  location: 'global'
}]

// SOA Record
resource soaRecord 'Microsoft.Network/privateDnsZones/SOA@2020-06-01' existing = [for (zone, i) in privateDnsZoneNames: {
  name: '@'
  parent: privateDnsZones[i]
}]

// SOA Locks
resource soaLocks 'Microsoft.Authorization/locks@2020-05-01' = [for (zone, i) in privateDnsZoneNames: {
  name: 'CanNotDeleteLock'
  scope: soaRecord[i]
  properties: {
    level: 'CanNotDelete'
  }
}]

//Outputs
output privateDnsZoneIds array = [for (zone, i) in privateDnsZoneNames: privateDnsZones[i].id]
