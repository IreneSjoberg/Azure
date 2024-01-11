targetScope='subscription'

// Parameters
@description('IP range for environment to be deployed within.')
param addressSpace string

param location string = 'swedencentral'
param archiveId string = '/subscriptions/15657746-89b9-4f62-ad76-76f1d110a14c/resourceGroups/core-rg/providers/Microsoft.Storage/storageAccounts/corearchivest'
param logAnalyticsWorkspaceId string = '/subscriptions/15657746-89b9-4f62-ad76-76f1d110a14c/resourceGroups/core-rg/providers/Microsoft.OperationalInsights/workspaces/core-log'
param remoteVnetPeeringIds array = [
  '/subscriptions/15657746-89b9-4f62-ad76-76f1d110a14c/resourceGroups/core-rg/providers/Microsoft.Network/virtualNetworks/core-vnet'
  '/subscriptions/15657746-89b9-4f62-ad76-76f1d110a14c/resourceGroups/mgmt-core-rg/providers/Microsoft.Network/virtualNetworks/mgmt-core-vnet'
]

param timestamp string = utcNow('yyyyMMdd-HHmm')

@description('Nameprefix for all resources deployed.')
param namePrefix string

// Variables
var funcSnetName = '${namePrefix}-func-snet'
var nsgName = '${namePrefix}-nsg'
var snetName = '${namePrefix}-snet'
var vnetName = '${namePrefix}-vnet'
var storageAccountName = replace('${namePrefix}-st', '-', '')
var appName = '${namePrefix}-theazures-func'
var vaultName = '${namePrefix}-rsv'

var regionCodes = {
  swedencentral: 'sdc'
  westeurope: 'weu'
}

var privateDnsZoneIds = {
  blob: '/subscriptions/15657746-89b9-4f62-ad76-76f1d110a14c/resourceGroups/core-dnszones-rg/providers/Microsoft.Network/privateDnsZones/privatelink.blob.${environment().suffixes.storage}'
  file: '/subscriptions/15657746-89b9-4f62-ad76-76f1d110a14c/resourceGroups/core-dnszones-rg/providers/Microsoft.Network/privateDnsZones/privatelink.file.${environment().suffixes.storage}'
  table: '/subscriptions/15657746-89b9-4f62-ad76-76f1d110a14c/resourceGroups/core-dnszones-rg/providers/Microsoft.Network/privateDnsZones/privatelink.table.${environment().suffixes.storage}'
  sites: '/subscriptions/15657746-89b9-4f62-ad76-76f1d110a14c/resourceGroups/core-dnszones-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurewebsites.net'
  rsv: '/subscriptions/15657746-89b9-4f62-ad76-76f1d110a14c/resourceGroups/core-dnszones-rg/providers/Microsoft.Network/privateDnsZones/privatelink.${regionCodes[location]}.backup.windowsazure.com'
}

// Deploy Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = { 
  name: '${namePrefix}-rg'
  location: location
}

resource coreDnsZonesRg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: 'core-dnszones-rg'
}

// Deploy Infrastructure
module infrastructure 'infrastructure.bicep' = {
  name: 'infraModule-${timestamp}'
  scope: resourceGroup
  params: {
    addressSpace: addressSpace
    appName: appName
    archiveId: archiveId
    funcSnetName: funcSnetName
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    nsgName: nsgName
    privateDnsZoneIds: privateDnsZoneIds
    remoteVnetPeeringId: remoteVnetPeeringIds
    snetName: snetName
    storageAccountName: storageAccountName
    vnetName: vnetName
  }
}

// Deploy Recovery Service Vault
module recoveryServiceVault 'recoveryservicevault.bicep' = {
  name: 'recoveryModule-${timestamp}' 
  scope: resourceGroup
  params: {
    archiveId: archiveId
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    vaultName: vaultName
  }
}

// Deploy Private Endpoint for RSV
module rsvPrivateEndpoint 'pep.bicep' = {
  name: 'privateEndpoints-${timestamp}'
  scope: resourceGroup
  params: {
    endpoints: [
      {
        resourceId: recoveryServiceVault.outputs.rsvId
        groupIds: ['AzureBackup']
        privateDnsZoneId: privateDnsZoneIds.rsv
      }
    ]
    location: location
    snetId: infrastructure.outputs.snetId
  }
}

// Deploy Protection Container
module protectionContainer 'protectioncontainer.bicep' = {
  name: 'protectionContainer-${timestamp}' 
  scope: resourceGroup
  params: {
    rsvId: recoveryServiceVault.outputs.rsvId
    storageAccountId: infrastructure.outputs.stId
  }
}

// Deploy Vnet Peering
module localToRemoteVnetPeering 'vnet-peering.bicep' = {
  scope: resourceGroup
  name: 'localtoRemoteVnetPeerings-${timestamp}'
  params: {
    localVnetId: infrastructure.outputs.vnetId
    remoteVnetIds: remoteVnetPeeringIds
  }
}

resource remoteVnetRg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = [for (remoteVnet, i) in remoteVnetPeeringIds: {
  name: split(remoteVnet, '/')[4]
}]

module remoteToLocalVnetPeering 'vnet-peering.bicep' = [for (remoteVnet, i) in remoteVnetPeeringIds: {
  scope: remoteVnetRg[i]
  name: 'remoteToLocalVnetPeerings-${timestamp}'
  params: {
    localVnetId: remoteVnet
    remoteVnetIds: [infrastructure.outputs.vnetId]
  }
}]

// Deploy Core Vnet Links
module privateDnsZoneLinksCore 'vnetLinks.bicep' = {
  name: 'vnetlinkCoreModule-${timestamp}'
  scope: coreDnsZonesRg
  params: {
    privateDnsZoneIds: [
      privateDnsZoneIds.blob
      privateDnsZoneIds.file
      privateDnsZoneIds.table
      privateDnsZoneIds.sites
      privateDnsZoneIds.rsv
    ]
    vnetId: infrastructure.outputs.vnetId
  }
}

// Outputs
output vnetId string = infrastructure.outputs.vnetId
output snetId string = infrastructure.outputs.snetId 
output funcSnetId string = infrastructure.outputs.funcSnetId
output stId string = infrastructure.outputs.stId
output funcId string = infrastructure.outputs.funcId
output pepIds array = infrastructure.outputs.pepIds
output rsvId string = recoveryServiceVault.outputs.rsvId
output rsvPepId array = rsvPrivateEndpoint.outputs.pepIds
output protectionContainerId string = protectionContainer.outputs.protectionContainerId

// Output Essential for Pipeline
output resourceGroupName string = resourceGroup.name
output rsvName string = recoveryServiceVault.outputs.rsvName
output storageAccountName string = infrastructure.outputs.stName
