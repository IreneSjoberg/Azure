// Parameters
@description('Region for the deployed resources.')
param location string = resourceGroup().location

@description('Resource Names.')
param vnetMgmtName string

@description('Resource Ids.')
param storageAccountId string
param logAnalyticsWorkspaceId string

// Variables
@description ('Login for VM')
var vnetAdressPrefix = '10.0.1.0/24'
var snet1Name = '${vnetMgmtName}-snet'
var snet1Prefix = '10.0.1.0/25'

// NSG
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${vnetMgmtName}-nsg'
  location: location
  properties: {
    securityRules: loadJsonContent('nsgSecurityRules.json')
  }
}

// Vnet
resource vnetMgmt 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetMgmtName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAdressPrefix
      ]
    }
    subnets: [
      {
        name: snet1Name
        properties: {
          addressPrefix: snet1Prefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// Diagnostic settings
resource nsgDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${vnetMgmtName}-nsg-diag'
  scope: nsg
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
  name: '${vnetMgmtName}-diag'
  scope: vnetMgmt
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
output vnetMgmtId string = vnetMgmt.id
output subnetMgmtId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetMgmt.name, snet1Name)
