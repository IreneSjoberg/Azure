// Parameters
@description('Region for the deployed resources.')
param location string

@description('Resource Names.')
param storageAccountName string

@description('Resource Ids.')
param logAnalyticsWorkspaceId string

// StorageAccount
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Cool'
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'disabled'
    supportsHttpsTrafficOnly: true
  }

  // Blob
resource blobService 'blobServices' existing = {
  name: 'default'
}

// Fileshare
resource fileService 'fileServices' = {
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 1
    }
  }
}

// Table
resource tableService 'tableServices' existing = {
  name: 'default'
}
}

// Diagnostic settings
resource storageAccountBlobDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccount.name}-blob-diag'
  scope: storageAccount::blobService
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
    storageAccountId: storageAccount.id
    workspaceId: logAnalyticsWorkspaceId
  }
}

resource storageAccountFileDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccount.name}-file-diag'
  scope: storageAccount::fileService
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
    storageAccountId: storageAccount.id
    workspaceId: logAnalyticsWorkspaceId
  }
}

resource storageAccountTableDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccount.name}-table-diag'
  scope: storageAccount::tableService
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
    storageAccountId: storageAccount.id
    workspaceId: logAnalyticsWorkspaceId
  }
}


// Rule Lifecycle
resource LifecycleRule 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'LifecycleRuleCoreLogSt'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 10
                }
                tierToArchive: {
                  daysAfterLastTierChangeGreaterThan: 5
                  daysAfterModificationGreaterThan: 30
                }
                delete: {
                  daysAfterModificationGreaterThan: 60
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
            }
          }
        }
      ]
    }
  }
}

// Outputs
output stId string = storageAccount.id
