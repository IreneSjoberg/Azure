// Parameters
@description ('Location for all resources.')
param location string

@description('Resource Names.')
param keyVaultName string
param vmName string

@description('Resource Ids.')
param storageAccountId string
param logAnalyticsWorkspaceId string
param subnetId string

param timestamp string = utcNow('yyyyMMdd-HHmm')

// Variables
@description ('Keyvault secret for VM password')
var adminPasswordSecretName = 'adminPassword'

// Keyvault
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location 
  properties: {
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enableSoftDelete: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'disabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
  }

    resource secret 'secrets' = {
      name: adminPasswordSecretName
      properties: {
        value: 'Testtest123!'
      }
    }
}

// Deploy Management
module managementVm 'vm-mgmt.bicep' = {
  name: '${vmName}-${timestamp}'
  params: {
    location: location
    vmName: vmName
    vmAdminPassword: kv.getSecret(kv::secret.name)
    subnetId: subnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    storageAccountId: storageAccountId
  }
}

// Diagnostic settings
resource kvDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVaultName}-diag'
  scope: kv
  properties: {
    logs: [
      {
        enabled: true
        categoryGroup: 'audit'
      } 
      {
        enabled: true
        categoryGroup: 'allLogs'
      }
    ]
    storageAccountId: storageAccountId
    workspaceId: logAnalyticsWorkspaceId
  }
}

output kvId string = kv.id
