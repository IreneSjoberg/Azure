@description('Resource ID of the local VNET to be peered against the remote VNET id.')
param localVnetId string

@description('Resource ID of the remote VNET to be peered against the local VNET id.')
param remoteVnetIds array

// Get the local VNET
resource localVnet 'Microsoft.Network/virtualNetworks@2023-06-01' existing = {
  name: split(localVnetId, '/')[8]
}

// Deploy local to remote peering
resource vnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-04-01' = [for (vnetId, i) in remoteVnetIds: {
  name: '${split(vnetId, '/')[8]}-peer'
  parent: localVnet
  properties: {
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: vnetId
    }
  }
}]

// Outputs
output vnetPeerings array = [for (vnetId, i) in remoteVnetIds: {
  id: vnetPeering[i].id
  peeringState: vnetPeering[i].properties.peeringState
  syncLevel: vnetPeering[i].properties.peeringSyncLevel
}]
