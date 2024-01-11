@description('The region that will be used for the deployed resources.')
param location string

@description('Name of the Azure Firewall to be deployed.')
param firewallName string

@description('Resource ID of the Azure Firewall Policy to be used by the Azure Firewall.')
param firewallPolicyId string

@description('Resource ID of the subnet that will be used by the deployed Azure Firewall.')
param firewallSubnetId string

@description('Tags that will be added on the deployed resources.')
param tags object = {}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-06-01' existing = {
  name: split(firewallPolicyId, '/')[8]
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: '${firewallName}-pip'
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
  sku: {
     name: 'Standard'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-04-01' = {
  name: firewallName
  location: location
  tags: tags
  properties: {
    firewallPolicy: {
      id: firewallPolicy.id
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: {
            id: firewallPublicIp.id
          }
          subnet: {
            id: firewallSubnetId
          }
        }
      }
    ]
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
  }
}

// Outputs
output afwpId string = firewallPolicy.id
output afwPipId string = firewallPublicIp.id
output afwId string = firewall.id
output afwPublicIp string = firewallPublicIp.properties.ipAddress
output afwPrivatIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress

