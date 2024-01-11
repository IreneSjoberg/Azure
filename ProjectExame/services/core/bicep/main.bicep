targetScope = 'subscription'

// Parameters
@description('Naming standards.')
param coreName string = 'core'
param coreMgmtName string = 'mgmt-core'

@description('Region for the deployed resources.')
param location string = 'swedencentral'

@description('Regioncode for the deployed resources.')
param regionCode string = 'sdc'

@description('Resource Names.')
param storageAccountName string = '${coreName}archivest'
param logWorkspaceName string = '${coreName}-log'
param keyVaultName string = '${coreMgmtName}-kv'
param vmName string = '${coreMgmtName}-vm'
param vnetCoreName string = '${coreName}-vnet'
param vnetMgmtName string = '${coreMgmtName}-vnet'

param timestamp string = utcNow('yyyyMMdd-HHmm')

// Resource Groups
resource coreDnsZonesRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'core-dnszones-rg'
  location: location
}

resource coreLogRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${coreName}-rg'
  location: location
}

resource coreMgmtRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${coreMgmtName}-rg'
  location: location
}

// Deploy DNS Zones
module privateDNSZones 'privatednszones.bicep' = {
  name: 'privateDNSZonesModule-${timestamp}'
  scope: coreDnsZonesRg
  params: {
    regionCode: regionCode
  }
}

// Deploy Log Analytics Workspace
module logWorkspace 'log.bicep' = {
  name: 'logSpaceWorkspaceModule-${timestamp}'
  scope: coreLogRg
  params: {
    logWorkspace: logWorkspaceName
    location: location
  }
}

// Deploy StorageAccount
module coreStorageAccount 'storageaccount-core.bicep' = {
  name: 'storageAccountModule-${timestamp}'
  scope: coreLogRg
  params: {
    location: location
    logAnalyticsWorkspaceId: logWorkspace.outputs.logId
    storageAccountName: storageAccountName
  }
}

// Deploy Vnets
module coreVnet 'vnet-core.bicep' = {
  name: '${vnetCoreName}-${timestamp}'
  scope: coreLogRg
  params: {
    location: location
    logAnalyticsWorkspaceId: logWorkspace.outputs.logId
    storageAccountId: coreStorageAccount.outputs.stId
    vnetCoreName: vnetCoreName
  }
}

module managementVnet 'vnet-mgmt.bicep' = {
  name: '${vnetMgmtName}-${timestamp}'
  scope: coreMgmtRg
  params: {
    location: location
    logAnalyticsWorkspaceId: logWorkspace.outputs.logId
    storageAccountId: coreStorageAccount.outputs.stId
    vnetMgmtName: vnetMgmtName
  }
}


// Deploy Peps
module coreStorageAccountPep 'pep.bicep' = {
  name: 'privateEndpoints-${timestamp}'
  scope: coreLogRg
  params: {
    location: location
    endpoints: [
      {
        resourceId: coreStorageAccount.outputs.stId
        privateEndpointName: '${split(coreStorageAccount.outputs.stId, '/')[8]}-blob-pep'
        groupIds: ['blob']
        privateDnsZoneId: resourceId(subscription().subscriptionId, coreDnsZonesRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.${environment().suffixes.storage}')
      }
    ]
    subnetId: coreVnet.outputs.subnetCoreId
  }
}

module mgmtKeyVaultPep 'pep.bicep' = {
  name: 'privateEndpoints-${timestamp}'
  scope: coreMgmtRg
  params: {
    location: location
    endpoints: [
      {
        resourceId: coreManagement.outputs.kvId
        groupIds: ['vault']
        privateDnsZoneId: resourceId(subscription().subscriptionId, coreDnsZonesRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')
      }
    ]
    subnetId: managementVnet.outputs.subnetMgmtId
  }
}

// Deploy Peerings
module vnetCorePeering 'vnet-peering.bicep' = {
  name: 'vnet-core-peering-${timestamp}'
  scope: coreLogRg
  params: {
    localVnetId: coreVnet.outputs.vnetCoreId
    remoteVnetIds: [managementVnet.outputs.vnetMgmtId]
  }
}

module vnetMgmtPeering 'vnet-peering.bicep' = {
  name: 'vnet-mgmt-peering-${timestamp}'
  scope: coreMgmtRg
  params: {
    localVnetId: managementVnet.outputs.vnetMgmtId
    remoteVnetIds: [coreVnet.outputs.vnetCoreId]
  }
}

// Deploy Mgmt RG
module coreManagement 'resource-mgmt.bicep' = {
  name: '${coreMgmtName}-${timestamp}'
  scope: coreMgmtRg
  params: {
    location: location
    keyVaultName: keyVaultName
    vmName: vmName
    logAnalyticsWorkspaceId: logWorkspace.outputs.logId
    storageAccountId: coreStorageAccount.outputs.stId
    subnetId: managementVnet.outputs.subnetMgmtId
  }
}

// Deploy Vnetlinks
module privateDnsZoneLinksCore 'vnetLinks.bicep' = {
  name: 'vnetlinkCoreModule-${timestamp}'
  scope: coreDnsZonesRg
  params: {
    privateDnsZoneIds: privateDNSZones.outputs.privateDnsZoneIds
    vnetId: coreVnet.outputs.vnetCoreId
  }
}

module privateDnsZoneLinksMgmt 'vnetLinks.bicep' = {
  name: 'vnetlinkMgmtModule-${timestamp}'
  scope: coreDnsZonesRg
  params: {
    privateDnsZoneIds: privateDNSZones.outputs.privateDnsZoneIds
    vnetId: managementVnet.outputs.vnetMgmtId
  }
}
