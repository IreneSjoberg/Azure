@description('The region that will be used for the deployed resources.')
param location string

@description('Name of the Azure Firewall Policy to be deployed.')
param firewallPolicyName string

@description('Enables DNS Proxy if true.')
param enableProxy bool = true

@description('The threat intelligence mode that will be used for the firewall policy.')
@allowed(['Alert', 'Deny', 'Off'])
param threatIntelMode string = 'Alert'

@description('Tags that will be added on the deployed resources.')
param tags object = {}

// Deploy Azure Firewall Policy
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-06-01' = {
  name: firewallPolicyName
  location: location
  tags: tags
  properties: {
    dnsSettings: {
      enableProxy: enableProxy
    }
    threatIntelMode: threatIntelMode
  }
}

// Outputs
output afwpId string = firewallPolicy.id


