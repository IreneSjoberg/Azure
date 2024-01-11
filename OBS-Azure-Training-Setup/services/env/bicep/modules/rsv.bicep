@description('The region that will be used for the deployed resources.')
param location string

@description('Name of the Recovery Services Vault that will be deployed.')
param rsvName string

@description('Tags that will be added on the deployed resources.')
param tags object = {}

resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: rsvName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }

  // Deploy RSV Backup policy
  resource rsvFileShareDailyPolicy 'backupPolicies' = {
    name: 'DailyPolicy'
    properties: {
      backupManagementType: 'AzureStorage'
      retentionPolicy: {
        retentionPolicyType: 'LongTermRetentionPolicy'
        dailySchedule: {
          retentionTimes: [
            '2023-12-01T11:30:00Z'
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
          '2023-12-01T11:30:00Z'
        ]
        scheduleWeeklyFrequency: 0
      }
      timeZone: 'UTC'
      workLoadType: 'AzureFileShare'
    }
  }
}

// Outputs
output rsvId string = recoveryServicesVault.id
output rsvName string = recoveryServicesVault.name
output rsvBackupPolicyId string = recoveryServicesVault::rsvFileShareDailyPolicy.id
