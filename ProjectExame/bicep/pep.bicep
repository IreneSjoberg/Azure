// Parameters
@description('Region for the deployed resources.')
param location string

@description('Resource ID of the subnet where the created private endpoints will exist.')
param snetId string

@description('Array containing endpoint data for private endpoints to be created.')
param endpoints array


// Private Endpoints
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = [for (endpoint, i) in endpoints: {
  name: contains(endpoint, 'privateEndpointName') ? endpoint.privateEndpointName : '${split(endpoint.resourceId, '/')[8]}-pep'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: contains(endpoint, 'privateEndpointName') ? endpoint.privateEndpointName : '${split(endpoint.resourceId, '/')[8]}-pl'
        properties: {
          groupIds: endpoint.groupIds
          privateLinkServiceId: endpoint.resourceId
        }
      }
    ]
    subnet: {
      id: snetId
    }
  }
}]

resource dnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-06-01' = [for (endpoint, i) in endpoints: {
  name: 'dnsZoneGroups'
  parent: privateEndpoint[i]
  properties: {
    privateDnsZoneConfigs: [
      {
        name: contains(endpoint, 'privateEndpointName') ? endpoint.privateEndpointName : '${split(endpoint.resourceId, '/')[8]}-con'
        properties: {
          privateDnsZoneId: endpoint.privateDnsZoneId
        }
      }
    ]
  }
}]

// Outputs
output pepIds array = [for (endpoint, i) in endpoints: privateEndpoint[i].id ]
