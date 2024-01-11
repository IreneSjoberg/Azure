@description('The region that will be used for the deployed resources.')
param location string = resourceGroup().location

@description('Array containing data for endpoints to be deployed.')
param endpoints array

@description('Subnet ID from where the private IP for the private endpoint will be taken')
param subnetId string

@description('Tags applied to the Azure resource')
param tags object = {}

// Deploy PEP
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = [for (endpoint, i) in endpoints: {
  name: endpoint.?privateEndpointName ?? '${split(endpoint.resourceId, '/')[8]}-pep'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: endpoint.?privateEndpointName ?? '${split(endpoint.resourceId, '/')[8]}-pep'
        properties: {
          groupIds: endpoint.groupIds
          privateLinkServiceId: endpoint.resourceId
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}]

// Deploy PEP privateDnsZoneGroup
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = [for (endpoint, i) in endpoints: {
  name: 'default'
  parent: privateEndpoint[i]
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${privateEndpoint[i].name}-con'
        properties: {
          privateDnsZoneId: endpoint.privateDnsZoneId
        }
      }
    ]
  }
}]

// Output
output pepIds array = [for (endpoint, i) in endpoints: privateEndpoint[i].id]

