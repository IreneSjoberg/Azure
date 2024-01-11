// Parameters
param addressSpace string

@description('Region for the deployed resources.')
param location string

@description('Resource ID of the storage account where the logs will be archived.')
param archiveId string

@description('Resource ID of the log analytic workspace to which logs will be sent.')
param logAnalyticsWorkspaceId string

@description('Resource ID:s of peered virtual networks')
param remoteVnetPeeringId array

param funcSnetName string
param nsgName string
param snetName string
param vnetName string

// NGS
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: nsgName
  location: location
}

// Vnet
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [addressSpace]
    }
    subnets: [
      {
        name: snetName
        properties: {
          addressPrefix: cidrSubnet(addressSpace, 27, 0)
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: funcSnetName
        properties: {
          addressPrefix: cidrSubnet(addressSpace, 27, 1)
          delegations: [
            {
              name: funcSnetName
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
              type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
            }
          ]
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
  
  resource vnetPeering 'virtualNetworkPeerings' = [for vnetId in remoteVnetPeeringId: {
    name: '${split(vnetId, '/')[8]}-peer'
    properties: {
      allowVirtualNetworkAccess: true
      remoteVirtualNetwork: {
        id: vnetId
      }
    }
  }]
}

// Diagnostic settings
resource nsgDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${vnetName}-diag'
  scope: nsg
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: archiveId
    logs: [
      {
        enabled: true
        categoryGroup: 'allLogs'
      }
    ]
  }
}

resource vnetDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${vnetName}-diag'
  scope: vnet
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: archiveId
    logs: [
      {
        enabled: true
        categoryGroup: 'allLogs'
      }
    ]
  }
}

// Outputs
output nsgId string = nsg.id
output vnetId string = vnet.id
output vnetName string = vnet.name
output snetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, snetName) 
output snetName string = snetName
output funcSnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, funcSnetName)
output funcSnetName string = funcSnetName
