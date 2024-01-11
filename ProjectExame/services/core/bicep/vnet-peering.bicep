// Parameters
@description('Resource Ids.')
param localVnetId string
param remoteVnetIds array

// Vnet
resource vnetCore 'Microsoft.Network/virtualNetworks@2023-06-01' existing = {
  name: split(localVnetId, '/')[8]

  resource vnetCorePeering 'virtualNetworkPeerings' = [for vnetId in remoteVnetIds: {
    name: '${split(vnetId, '/')[8]}-peer'
    properties: {
      allowVirtualNetworkAccess: true
      remoteVirtualNetwork: {
        id: vnetId
      }
    }
  }]
}
