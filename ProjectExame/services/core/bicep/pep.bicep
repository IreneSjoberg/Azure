// Parameters
@description('Region for the deployed resources.')
param location string

@description('Array containing endpoint data for private endpoints to be created.')
param endpoints array

@description('Resource ID of the subnet where the created private endpoints will exist.')
param subnetId string


// Private Endpoint
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-06-01' = [for (endpoint, i) in endpoints: {
  name: endpoint.?privateEndpointName ?? '${split(endpoint.resourceId, '/')[8]}-pep'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: endpoint.?privateEndpointName ?? '${split(endpoint.resourceId, '/')[8]}-pl'
        properties: {
          privateLinkServiceId: endpoint.resourceId
          groupIds: endpoint.groupIds
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}]

// DNS Zone Groups
resource dnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = [for (endpoint, i) in endpoints: {
  name: 'dnsZoneGroups'
  parent: privateEndpoint[i]
  properties: {
    privateDnsZoneConfigs: [
      {
        name: endpoint.?privateEndpointName ?? '${split(endpoint.resourceId, '/')[8]}-con'
        properties: {
          privateDnsZoneId: endpoint.privateDnsZoneId
        }
      }
    ]
  }
}]

// Output
output pepIds array = [for (endpoint, i) in endpoints: privateEndpoint[i].id ]
