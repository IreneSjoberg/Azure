// Parameters
@description('Region for the deployed resources.')
param location string

@description('Resource ID of the storage account where the logs will be archived.')
param archiveId string

@description('Resource ID of the log analytic workspace to which logs will be sent.')
param logAnalyticsWorkspaceId string

@description('Enable CRR (Works if vault has not registered any backup instance)')
param enableCRR bool = true

param vaultName string

@allowed([
  'LocallyRedundant'
  'GeoRedundant'
])
param vaultStorageType string = 'GeoRedundant'

// Variables
var skuName = 'RS0'
var skuTier = 'Standard'

// Recovery Service Vault
resource recoveryServiceVault 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: vaultName
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    publicNetworkAccess: 'Disabled' 
  }

  resource vaultDailyPolicy 'backupPolicies@2023-04-01' = {
    name: 'DailyPolicy'
    properties: {
      backupManagementType: 'AzureStorage'
      retentionPolicy: {
        retentionPolicyType: 'LongTermRetentionPolicy'
        dailySchedule: {
          retentionTimes: [
            '2023-12-18T11:30:00Z'
          ]
          retentionDuration: {
            count: 14
            durationType: 'Days'
          }
        }
      }
      schedulePolicy: {
        schedulePolicyType: 'SimpleSchedulePolicy'
        scheduleRunFrequency: 'Daily'
        scheduleRunTimes: [
          '2023-12-18T11:30:00Z'
        ]
      }
      timeZone: 'UTC'
      workLoadType: 'AzureFileShare'
    }
  }

  resource vaultName_vaultstorageconfig 'backupstorageconfig@2023-04-01' = {
    name: 'vaultstorageconfig'
    properties: {
      crossRegionRestoreFlag: enableCRR
      storageModelType: vaultStorageType
    }
  }
}

// Diagnostic settings
resource recoveryServiceVaultDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${recoveryServiceVault.name}-recovery-diag'
  scope: recoveryServiceVault
  properties: {
    logs: [
      {
        enabled: true
        categoryGroup: 'allLogs'
      }
    ]
    storageAccountId: archiveId
    workspaceId: logAnalyticsWorkspaceId
  }
} 

// Outputs
output rsvId string = recoveryServiceVault.id
output rsvName string = recoveryServiceVault.name
