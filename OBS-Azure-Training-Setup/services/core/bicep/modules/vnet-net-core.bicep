@description('The region that will be used for the deployed resources.')
param location string

@description('Naming prefix that will be used for all deployed resources.')
param namePrefix string

@description('The VNET address space that will be used for all deployed resources.')
param vnetAddressPrefix string

@description('Tags that will be added on the deployed resources.')
param tags object = {}

// Variables
var vnetName = '${namePrefix}-vnet'

resource vnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: cidrSubnet(vnetAddressPrefix, 26, 0) // Get the first /26 subnet from VNET address space
        }
      }
    ]
  }
}

// Outputs
output vnetId string = vnet.id
output vnetName string = vnet.name
output vnetAddressSpace string = vnet.properties.addressSpace.addressPrefixes[0]
output afwSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'AzureFirewallSubnet')
