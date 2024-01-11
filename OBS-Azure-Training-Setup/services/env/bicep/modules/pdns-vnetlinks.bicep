// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/privatednszones/virtualnetworklinks?pivots=deployment-language-bicep

@description('Resource IDs of the PDNS zones where the VNET-links will be created.' )
param privateDnsZoneIds array

@description('Resource ID of the VNET that will be VNET-linked to the PDNS zone(s).')
param vnetId string

@description('Enables auto-registration of virtual machine records in the virtual network in the Private DNS zone.')
param registrationEnabled bool = false

@description('Tags that will be added on the deployed resources.')
param tags object = {}

// Variables
var vnetLinkName = '${split(vnetId, '/')[8]}-link'

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = [for (zone, i) in privateDnsZoneIds: {
  name: split(zone, '/')[8]
}]

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zone, i) in privateDnsZoneIds: {
  name: vnetLinkName
  parent: privateDnsZone[i]
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: vnetId
    }
  }
}]

// Outputs
output vnetLinkIds array = [for (zone, i) in privateDnsZoneIds: privateDnsZoneVnetLink[i].id ]
