
@description('Resource ID of the existent Azure Firewall Policy to which the ruleCollectionGroups will be added')
param firewallPolicyId string

@description('The network CIDRs that will be allowed as source for the rules.')
param allowedSourceNetworks array

// Get existent firewall policy
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-06-01' existing = {
  name: split(firewallPolicyId, '/')[8]
}

// Deploy ruleCollectionGroup and add to firewall policy
resource ruleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-06-01' = {
  name: 'BaselineRules'
  parent: firewallPolicy
  properties: {
    priority: 2500
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'VmBaselineOutboundNetwork'
        priority: 2501
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'DNS-NTP'
            description: 'Allow DNS-NTP'
            sourceAddresses: allowedSourceNetworks
            ipProtocols: ['UDP']
            destinationPorts: ['53','123']
            destinationAddresses: ['*']
          }
          {
            ruleType: 'NetworkRule'
            name: 'HTTP-HTTPS'
            description: 'Allow HTTP-HTTPS'
            sourceAddresses: allowedSourceNetworks
            ipProtocols: ['TCP']
            destinationPorts: ['80','443']
            destinationAddresses: ['*']
          }
          {
            ruleType: 'NetworkRule'
            name: 'AzureActiveDirectory-AzureMonitor'
            description: 'Allow AzureActiveDirectory-AzureMonitor'
            sourceAddresses: allowedSourceNetworks
            ipProtocols: ['TCP','UDP']
            destinationPorts: ['*']
            destinationAddresses: ['AzureActiveDirectory', 'AzureMonitor']
          }
        ]
      }
    ]
  }
}

// Outputs
output firewallPolicyId string = firewallPolicy.id
output ruleCollectionGroupId string = ruleCollectionGroup.id
