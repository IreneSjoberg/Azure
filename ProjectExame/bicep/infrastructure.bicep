// Parameters
@description('IP range for environment to be deployed within.')
param addressSpace string

@description('Region for the deployed resources.')
param location string = resourceGroup().location

@description('Resource ID of the storage account where the logs will be archived.')
param archiveId string

@description('Resource ID of the log analytic workspace to which logs will be sent.')
param logAnalyticsWorkspaceId string

@description('Resource ID:s of peered virtual networks')
param remoteVnetPeeringId array

param nsgName string
param vnetName string
param snetName string
param funcSnetName string
param storageAccountName string
param appName string

param privateDnsZoneIds object

param timestamp string = utcNow('yyyyMMdd-HHmm')

// Deploy Network
module network 'network.bicep' = {
  name: 'network-${timestamp}'
  params: {
    addressSpace: addressSpace
    archiveId: archiveId
    funcSnetName: funcSnetName
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    nsgName: nsgName
    remoteVnetPeeringId: remoteVnetPeeringId
    snetName: snetName
    vnetName: vnetName
  }
}

// Deploy Storage Account
module storageAccount 'storageaccount.bicep' = {
  name: 'storageAccount-${timestamp}'
  params: {
    archiveId: archiveId
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    storageAccountName: storageAccountName
  }
}

// Deploy Function App
module functionApp 'functionapp.bicep' = {
  name: 'functionApp-${timestamp}'
  params: {
    appName: appName
    archiveId: archiveId
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    funcSnetId: network.outputs.funcSnetId
    storageAccountId: storageAccount.outputs.stId
    vnetId: network.outputs.vnetId
  }
}

// Deploy Private Endpoints
module privateEndpoints 'pep.bicep' = {
  name: 'privateEndpoints-${timestamp}'
  params: {
    location: location
    endpoints: [
      {
        resourceId: storageAccount.outputs.stId
        privateEndpointName: '${split(storageAccount.outputs.stId, '/')[8]}-blob-pep'
        groupIds: ['blob']
        privateDnsZoneId: privateDnsZoneIds.blob
      }
      {
        resourceId: storageAccount.outputs.stId 
        privateEndpointName: '${split(storageAccount.outputs.stId, '/')[8]}-file-pep'
        groupIds: ['file']
        privateDnsZoneId: privateDnsZoneIds.file
      }
      {
        resourceId: storageAccount.outputs.stId 
        privateEndpointName: '${split(storageAccount.outputs.stId, '/')[8]}-table-pep' 
        groupIds: ['table']
        privateDnsZoneId: privateDnsZoneIds.table
      }
      {
        resourceId: functionApp.outputs.funcId
        groupIds: ['sites']
        privateDnsZoneId: privateDnsZoneIds.sites
      }
    ]
    snetId: network.outputs.snetId
  }
}

// Outputs
output vnetId string = network.outputs.vnetId
output snetId string = network.outputs.snetId 
output funcSnetId string = network.outputs.funcSnetId
output stId string = storageAccount.outputs.stId
output stName string = storageAccount.outputs.stName
output funcId string = functionApp.outputs.funcId
output pepIds array = privateEndpoints.outputs.pepIds
