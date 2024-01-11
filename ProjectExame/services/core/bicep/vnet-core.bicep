// Parameters
@description('Region for the deployed resources.')
param location string

@description('Resource Names.')
param vnetCoreName string

@description('Resource Ids.')
param storageAccountId string
param logAnalyticsWorkspaceId string

// Variables
@description ('IP adresses')
var vnetPrefixes = '10.0.2.0/24'
var snet1Name ='${vnetCoreName}-snet'
var subnetPrefix = '10.0.2.0/25'

// NSG
resource nsgCore 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: '${vnetCoreName}-nsg'
  location: location
}

// Vnet
resource vnetCore 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetCoreName
  location: location 
  properties: {
    addressSpace: {
      addressPrefixes: [vnetPrefixes]
    }
    subnets: [
      {
        name: snet1Name
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsgCore.id
          }
        }
      }
    ]
  }
}

// Diagnostic settings
resource nsgCoreDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${vnetCoreName}-nsg-diag'
  scope: nsgCore
  properties: {
    logs: [
      {
        enabled: true
        categoryGroup: 'allLogs'
      }
    ]
    storageAccountId: storageAccountId
    workspaceId: logAnalyticsWorkspaceId
  }
}

resource vnetDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${vnetCoreName}-diag'
  scope: vnetCore
  properties: {
    logs: [
      {
        enabled: true
        categoryGroup: 'allLogs'
      }
    ]
    storageAccountId: storageAccountId
    workspaceId: logAnalyticsWorkspaceId
  }
}

// Outputs
output vnetCoreId string = vnetCore.id
output subnetCoreId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetCore.name, snet1Name)
