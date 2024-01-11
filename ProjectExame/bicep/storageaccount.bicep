// Parameters
@description('Region for the deployed resource.')
param location string

@description('Resource ID of the storage account where the logs will be archived.')
param archiveId string

@description('Resource ID of the log analytic workspace to which logs will be sent.')
param logAnalyticsWorkspaceId string

param storageAccountName string

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS' // vi kanske ska kolla på alternativa sku om vi ska vara kostnadseffektiva etc.?
  }
  kind: 'StorageV2' // vi kanske ska kolla på alternativa storage account kinds om vi ska vara kostnadseffektiva etc.?
  properties: {
    isHnsEnabled: true
    isSftpEnabled: true
    accessTier: 'Hot'
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true // Secure transfer required
  }

  resource blobService 'blobServices' existing = {
    name: 'default'
  }
 
  resource fileService 'fileServices' = {
    name: 'default'
    properties: {
      shareDeleteRetentionPolicy: {
        enabled: true
        days: 1
      }
    }
  }

  resource tableService 'tableServices' existing = {
    name: 'default'
 }
}

// Diagnostic settings
resource storageAccountBlobDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccount.name}-blob-diag'
  scope: storageAccount::blobService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: archiveId
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
  }
}

resource storageAccountFileDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccount.name}-file-diag'
  scope: storageAccount::fileService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: archiveId
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
  }
}

resource storageAccountTableDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccount.name}-table-diag'
  scope: storageAccount::tableService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: archiveId
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
  }
}

// Outputs
output stId string = storageAccount.id
output stName string = storageAccount.name
output blobServiceId string = storageAccount::blobService.id
output fileServiceId string = storageAccount::fileService.id
output tableServiceId string = storageAccount::blobService.id
