targetScope = 'subscription'

metadata template = {
  description: 'OBS Azure Training - Core setup example'
  author: 'fredrik.eliasson@basefarm-orange.com'
  version: '1.0.0'
}

@description('The region that will be used for the deployed resources.')
param location string

@description('Naming prefix that will be used for all deployed resources.')
@minLength(3)
@maxLength(11)
param namePrefix string

@description('The Private DNS zones that will be deployed.')
param privateDnsZoneNames array = [
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.table.${environment().suffixes.storage}'
  'privatelink.queue.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.vaultcore.azure.net'
  'privatelink.sdc.backup.windowsazure.com'
  'privatelink.azurewebsites.net'
  'scm.privatelink.azurewebsites.net'
]

@description('Tags that will be added on the deployed resources.')
param tags object = {}

@description('Timestamp for unique deployment names.')
param timestamp string = utcNow('yyyyMMdd-HHmmss')

// RG Variables
var coreDnsRgName = '${namePrefix}-dns-rg'
var coreLogRgName = '${namePrefix}-log-rg'
var coreMgmtRgName = '${namePrefix}-mgmt-rg'
var coreNetRegionRgName = '${namePrefix}-net-${location}-rg'

// Core MGMT Variables
var coreMgmtKvName = '${namePrefix}-mgmt-kv'
var coreMgmtVmName = '${namePrefix}-vm1'
var coreMgmtVmPasswordSecretName = '${coreMgmtVmName}-pw'
var coreMgmtVnetAddressPrefix = '10.200.0.0/24'

// Core Log Variables
var coreLogName = '${namePrefix}-log'
var coreLogStorageAccountName = replace('${namePrefix}archivest', '-', '')
var coreLogVnetAddressPrefix = '10.200.1.0/24'

// Core Region Networking variables
var coreFirewallPolicyName = '${namePrefix}-net-${location}-afwp'
var coreFirewallName = '${namePrefix}-net-${location}-afw'

// Deploy Core DNS RG
resource coreDnsRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: coreDnsRgName
  location: location
  tags: tags
}

// Deploy Core Log RG
resource coreLogRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: coreLogRgName
  location: location
  tags: tags
}

// Deploy Core MGMT RG
resource coreMgmtRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: coreMgmtRgName
  location: location
  tags: tags
}

// Deploy Core Network <Region> RG
resource coreNetRegionRg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: coreNetRegionRgName
  location: location
  tags: tags
}

/*
###### Core DNS ######
*/

// Deploy Core DNS - Private DNS Zones
module pdns 'modules/pdns.bicep' = {
  scope: coreDnsRg
  name: 'pdns-${timestamp}'
  params: {
    privateDnsZoneNames: privateDnsZoneNames
    tags: tags
  }
}

/*
###### Core MGMT ######
*/

// Deploy Core MGMT - VNET
module mgmtVnet 'modules/vnet.bicep' = {
  scope: coreMgmtRg
  name: 'mgmt-vnet-${timestamp}'
  params: {
    location: location
    namePrefix: '${namePrefix}-mgmt'
    securityRules: loadJsonContent('modules/mgmt-vm-security-rules.json')
    vnetAddressPrefix: coreMgmtVnetAddressPrefix
    tags: tags
  }
}

// Deploy Core MGMT - KV
module kv 'modules/kv.bicep' = {
  scope: coreMgmtRg
  name: 'mgmt-kv-${timestamp}'
  params: {
    location: location
    kvName: coreMgmtKvName
    kvSecrets: [
      {name: coreMgmtVmPasswordSecretName, value: '${uniqueString(coreMgmtRg.id, coreMgmtVmName)}!1aB'}
    ]
    tags: tags
  }
}

// Get Core MGMT - KV
resource kvExisting 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  scope: coreMgmtRg
  name: kv.outputs.kvName
}
 
// Deploy Core MGMT - MGMT VM
module mgmtVm 'modules/vm-win2022.bicep' = {
  scope: coreMgmtRg
  name: 'mgmt-${coreMgmtVmName}-${timestamp}'
  params: {
    location: location
    vmName: coreMgmtVmName
    vmSubnetId: mgmtVnet.outputs.subnetId
    adminPassword: kvExisting.getSecret(coreMgmtVmPasswordSecretName)
    tags: tags
  }
}

/*
###### Core Log ######
*/

// Deploy Core Log - VNET
module logVnet 'modules/vnet.bicep' = {
  scope: coreLogRg
  name: 'log-vnet-${timestamp}'
  params: {
    location: location
    namePrefix: '${namePrefix}-log'
    vnetAddressPrefix: coreLogVnetAddressPrefix
    tags: tags
  }
}

// Deploy Core Log - Log Analytics Workspace
module log 'modules/log.bicep' = {
  scope: coreLogRg
  name: 'log-${timestamp}'
  params: {
    location: location
    logName: coreLogName
    tags: tags
  }
}

// Deploy Core Log - Archiving Storage Account
module archiveSt 'modules/st-archive.bicep' = {
  scope: coreLogRg
  name: 'log-st-archive-${timestamp}'
  params: {
    location: location
    storageAccountName: coreLogStorageAccountName
    tags: tags
  }
}

/*
###### Core Region Networking ######
*/

// Deploy Core Region Networking - VNET
module regionNetworkingVnet 'modules/vnet-net-core.bicep' = {
  scope: coreNetRegionRg
  name: 'core-net-${location}-vnet-${timestamp}'
  params: {
    location: location
    namePrefix: '${namePrefix}-net-${location}'
    vnetAddressPrefix: '10.200.4.0/24'
    tags: tags
  }
}

// Deploy Azure Firewall Policy
module azureFirewallPolicy 'modules/afw/afwp.bicep' = {
  scope: coreNetRegionRg
  name: 'core-net-${location}-afwp-${timestamp}'
  params: {
    location: location
    firewallPolicyName: coreFirewallPolicyName
    tags: tags
  }
}

// Deploy Azure Firewall Policy Rules
module azureFirewallPolicyRules 'modules/afw/afwp-rules.bicep' = {
  scope: coreNetRegionRg
  name: 'core-net-${location}-afwp-rules-${timestamp}'
  params: {
    allowedSourceNetworks: [coreMgmtVnetAddressPrefix]
    firewallPolicyId: azureFirewallPolicy.outputs.afwpId
  }
}

// Deploy Azure Firewall
module azureFirewall 'modules/afw/afw.bicep' = {
  scope: coreNetRegionRg
  name: 'core-net-${location}-afw-rules-${timestamp}'
  dependsOn: [azureFirewallPolicyRules] // Await AFWP rules to be completed
  params: {
    location: location
    firewallName: coreFirewallName
    firewallPolicyId: azureFirewallPolicy.outputs.afwpId
    firewallSubnetId: regionNetworkingVnet.outputs.afwSubnetId
    tags: tags
  }
}

/*
###### Core Internal Networking ######
*/

// Deploy Private Endpoints for Core Log
module privateEndpointsLog 'modules/pep.bicep' = {
  scope: coreLogRg
  name: 'privateEndpoints-log-${timestamp}'
  params: {
    location: location
    endpoints: [
      {
        resourceId: archiveSt.outputs.stId
        groupIds: ['blob']
        privateDnsZoneId: resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.blob.${environment().suffixes.storage}')
        privateEndpointName: '${split(archiveSt.outputs.stId, '/')[8]}-blob-pep'
      }
    ]
    subnetId: logVnet.outputs.subnetId
    tags: tags
  }
}

// Deploy Private Endpoints for Core MGMT
module privateEndpointsMgmt 'modules/pep.bicep' = {
  scope: coreMgmtRg
  name: 'privateEndpoints-mgmt-${timestamp}'
  params: {
    location: location
    endpoints: [
      {
        resourceId: kv.outputs.kvId
        groupIds: ['vault']
        privateDnsZoneId: resourceId(subscription().subscriptionId, coreDnsRg.name, 'Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')
      }
    ]
    subnetId: mgmtVnet.outputs.subnetId
    tags: tags
  }
}

// Deploy VNET Peerings
module logVnetPeerings 'modules/vnetPeerings.bicep' = {
  name: 'peerings-log-${timestamp}'
  scope: coreLogRg
  params: {
    localVnetId: logVnet.outputs.vnetId
    remoteVnetIds: [mgmtVnet.outputs.vnetId]
  }
}

module mgmtVnetPeerings 'modules/vnetPeerings.bicep' = {
  name: 'peerings-mgmt-${timestamp}'
  scope: coreMgmtRg
  params: {
    localVnetId: mgmtVnet.outputs.vnetId
    remoteVnetIds: [
      logVnet.outputs.vnetId
      regionNetworkingVnet.outputs.vnetId
    ]
  }
}

module regionNetworkVnetPeerings 'modules/vnetPeerings.bicep' = {
  name: 'peerings-${location}-networking-${timestamp}'
  scope: coreNetRegionRg
  params: {
    localVnetId: regionNetworkingVnet.outputs.vnetId
    remoteVnetIds: [
      mgmtVnet.outputs.vnetId
    ]
  }
}

// Deploy Core Log - PDNS VNET-links
module logVnetPdnsLinks 'modules/pdns-vnetlinks.bicep' = {
  scope: coreDnsRg
  name: 'log-vnet-pdns-links-${timestamp}'
  dependsOn: [privateEndpointsLog, logVnetPeerings, mgmtVnetPeerings]
  params: {
    privateDnsZoneIds: pdns.outputs.privateDnsZoneIds
    vnetId: logVnet.outputs.vnetId
  }
}

// Deploy Core MGMT - PDNS VNET-links
module mgmtVnetPdnsLinks 'modules/pdns-vnetlinks.bicep' = {
  scope: coreDnsRg
  name: 'mgmt-vnet-pdns-links-${timestamp}'
  dependsOn: [privateEndpointsMgmt, mgmtVnetPeerings, logVnetPeerings]
  params: {
    privateDnsZoneIds: pdns.outputs.privateDnsZoneIds
    vnetId: mgmtVnet.outputs.vnetId
  }
}

// Main outputs
output privateDnsZoneIds array = pdns.outputs.privateDnsZoneIds
output logNsgId string = logVnet.outputs.nsgId
output logVnetId string = logVnet.outputs.vnetId
output logId string = log.outputs.logId
output stId string = archiveSt.outputs.stId
output kvId string = kv.outputs.kvId
output mgmtNsgId string = mgmtVnet.outputs.nsgId
output mgmtVnetId string = mgmtVnet.outputs.vnetId
output mgmtVmPipId string = mgmtVm.outputs.pipId
output mgmtVmNicId string = mgmtVm.outputs.nicId
output mgmtVmId string = mgmtVm.outputs.vmId

// Outputs for resource ID's that should get Diagnostic Settings enabled
output enableDiagnosticSettingsLogIds array = [
  logVnet.outputs.nsgId
  logVnet.outputs.vnetId
  log.outputs.logId
  archiveSt.outputs.stBlobServicesId
  kv.outputs.kvId
  mgmtVnet.outputs.nsgId
  mgmtVnet.outputs.vnetId
  mgmtVm.outputs.pipId
  azureFirewall.outputs.afwPipId
  azureFirewall.outputs.afwId
]
