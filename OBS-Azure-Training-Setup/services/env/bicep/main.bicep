targetScope = 'subscription'

metadata template = {
  description: 'OBS Azure Training - Env setup example'
  author: 'fredrik.eliasson@basefarm-orange.com'
  version: '1.0.0'
}

@description('The region that will be used for the deployed resources.')
param location string

@description('Naming prefix that will be used for all deployed resources.')
param namePrefix string

@description('Name of the resource group that contains the expected DNS resources for this template.')
param dnsRgName string

@description('The VNET address space that will be used for all deployed resources.')
param vnetAddressPrefix string

@description('Resource IDs of VNETs that the environment VNET will create bi-directional peerings for.')
param remoteVnetPeeringIds array = []

@description('Resource ID of the workspace that we will be sending logs to.')
param workspaceId string

@description('Network CIDRs that will be allowed to connect to restricted resources.')
param allowedNetworkCidrs array = ['10.200.0.0/24']

@description('Tags that will be added on the deployed resources.')
param tags object = {}

@description('Timestamp for unique deployment names.')
param timestamp string = utcNow('yyyyMMdd-HHmmss')

// Variables
var envResourceGroupName = '${namePrefix}-rg'
var storageAccountName = replace('${namePrefix}st', '-', '')
var functionAppName = '${namePrefix}-func'
var rsvName = '${namePrefix}-rsv'

// Get already existent Core DNS RG
resource coreDnsRg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: dnsRgName
}

// Deploy environment RG
resource envRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: envResourceGroupName
  location: location
  tags: tags
}

// Deploy Networking
module vnet 'modules/vnet.bicep' = {
  scope: envRg
  name: 'vnet-${timestamp}'
  params: {
    location: location
    namePrefix: namePrefix
    vnetAddressPrefix: vnetAddressPrefix
    tags: tags
  }
}

// Deploy Storage Account
module storageAccount 'modules/st.bicep' = {
  scope: envRg
  name: 'st-${timestamp}'
  params: {
    location: location
    storageAccountName: storageAccountName
    tags: tags
  }
}

// Deploy Function App
module funcApp 'modules/func.bicep' = {
  scope: envRg
  name: 'func-${timestamp}'
  params: {
    location: location
    functionAppName: functionAppName
    functionAppSubnetId: vnet.outputs.funcSubnetId
    storageAccountId: storageAccount.outputs.stId
    workspaceId: workspaceId
    allowedNetworkCidrs: allowedNetworkCidrs
    tags: tags
  }
}

// Deploy Recovery Services Vault
module rsv 'modules/rsv.bicep' = {
  scope: envRg
  name: 'rsv-${timestamp}'
  params: {
    location: location
    rsvName: rsvName
    tags: tags
  }
}

// Deploy Private Endpoints
module privateEndpoints 'modules/pep.bicep' = {
  scope: envRg
  name: 'privateEndpoints-${timestamp}'
  params: {
    location: location
    endpoints: [
      {
        resourceId: storageAccount.outputs.stId
        groupIds: ['blob']
        privateDnsZoneId: resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.${environment().suffixes.storage}')
        privateEndpointName: '${split(storageAccount.outputs.stId, '/')[8]}-blob-pep'
      }
      {
        resourceId: storageAccount.outputs.stId
        groupIds: ['file']
        privateDnsZoneId: resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.file.${environment().suffixes.storage}')
        privateEndpointName: '${split(storageAccount.outputs.stId, '/')[8]}-file-pep'
      }
      {
        resourceId: storageAccount.outputs.stId
        groupIds: ['table']
        privateDnsZoneId: resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.table.${environment().suffixes.storage}')
        privateEndpointName: '${split(storageAccount.outputs.stId, '/')[8]}-table-pep'
      }
      {
        resourceId: funcApp.outputs.funcId
        groupIds: ['sites']
        privateDnsZoneId: resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.azurewebsites.net')
      }
      {
        resourceId: rsv.outputs.rsvId
        groupIds: ['AzureBackup']
        privateDnsZoneId: resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.sdc.backup.windowsazure.com')
      }
    ]
    subnetId: vnet.outputs.envSubnetId
    tags: tags
  }
}

// Deploy local to remote VNET Peerings
module localVnetToRemotePeering 'modules/vnetPeerings.bicep' = [for remoteVnetId in remoteVnetPeeringIds: {
  name: 'peer-local-to-${split(remoteVnetId, '/')[8]}-${timestamp}'
  scope: envRg
  params: {
    localVnetId: vnet.outputs.vnetId
    remoteVnetIds: [remoteVnetId]
  }
}]

// Get remote VNET RG
resource remoteVnetRg 'Microsoft.Resources/resourceGroups@2023-07-01' existing = [for (remoteVnetId, i) in remoteVnetPeeringIds: {
  name: split(remoteVnetId, '/')[4]
}]

// Deploy remote to local VNET Peerings
module remoteVnetToLocalPeering 'modules/vnetPeerings.bicep' = [for (remoteVnetId, i) in remoteVnetPeeringIds: {
  name: 'peer-${split(remoteVnetId, '/')[8]}-to-local-${timestamp}'
  scope: remoteVnetRg[i]
  params: {
    localVnetId: remoteVnetId
    remoteVnetIds: [vnet.outputs.vnetId]
  }
}]

// Deploy environment PDNS VNET-links
module mgmtVnetPdnsLinks 'modules/pdns-vnetlinks.bicep' = {
  scope: coreDnsRg
  name: 'mgmt-vnet-pdns-links-${timestamp}'
  dependsOn: [privateEndpoints, localVnetToRemotePeering, remoteVnetToLocalPeering]
  params: {
    privateDnsZoneIds: [
      resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.${environment().suffixes.storage}')
      resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.file.${environment().suffixes.storage}')
      resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.table.${environment().suffixes.storage}')
      resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.azurewebsites.net')
      resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.sdc.backup.windowsazure.com')
    ]
    vnetId: vnet.outputs.vnetId
  }
}

// Register storage account as a backup container in RSV
module rsvProtectionContainer 'modules/rsv-container.bicep' = {
  scope: envRg
  name: 'rsv-container-${timestamp}'
  dependsOn: [privateEndpoints]
  params: {
    recoveryServicesVaultId: rsv.outputs.rsvId
    storageAccountId: storageAccount.outputs.stId
  }
}

// Main outputs
output rgId string = envRg.id
output nsgId string = vnet.outputs.nsgId
output vnetId string = vnet.outputs.vnetId
output stId string = storageAccount.outputs.stId
output appiId string = funcApp.outputs.appiId
output funcPlanId string = funcApp.outputs.funcPlanId
output funcId string = funcApp.outputs.funcId
output rsvId string = rsv.outputs.rsvId

// Outputs for resource ID's that should get Diagnostic Settings enabled
output enableDiagnosticSettingsLogIds array = [
  vnet.outputs.vnetId
  vnet.outputs.nsgId
  storageAccount.outputs.stBlobServicesId
  storageAccount.outputs.stFileServicesId
  storageAccount.outputs.stTableServicesId
  funcApp.outputs.appiId
  funcApp.outputs.funcId
  rsv.outputs.rsvId
]
