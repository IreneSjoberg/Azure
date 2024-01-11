@description('The region that will be used for the deployed resources.')
param location string

@description('Naming prefix that will be used for all deployed resources.')
param namePrefix string

@description('The VNET address space that will be used for all deployed resources.')
param vnetAddressPrefix string

@description('The security rules that will be used by the deployed NSG.')
param securityRules array = []

@description('Tags that will be added on the deployed resources.')
param tags object = {}

// Variables
var nsgName = '${namePrefix}-nsg'
var vnetName = '${namePrefix}-vnet'
var snetName = 'snet'
var funcSnetName = 'func-snet'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

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
        name: snetName
        properties: {
          addressPrefix: cidrSubnet(vnetAddressPrefix, 26, 0) // Get the first /26 subnet from VNET address space
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: funcSnetName
        properties: {
          addressPrefix: cidrSubnet(vnetAddressPrefix, 26, 1) // Get the second /26 subnet from VNET address space
          delegations: [
            {
              name: 'serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          networkSecurityGroup: {
            id: nsg.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// Outputs
output nsgId string = nsg.id
output vnetId string = vnet.id
output envSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, snetName)
output funcSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, funcSnetName)
