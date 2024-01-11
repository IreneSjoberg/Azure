@description('The region that will be used for the deployed resources.')
param location string

@description('The name of the storage account that will be deployed.')
param storageAccountName string

@description('Tags that will be added on the deployed resources.')
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'BlobStorage'
  properties: {
    accessTier: 'Cool'
    allowBlobPublicAccess: false
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: true
  }

  // Configure Blob Services
  resource blobServices 'blobServices' = {
    name: 'default'
    properties: {
      changeFeed: {
        enabled: true
      }
      isVersioningEnabled: true
    }
  }

  // Configure Lifecycle Management Policies
  resource lifecycleManagementPolicy 'managementPolicies' = {
    name: 'default'
    properties: {
      policy: {
        rules: [
          {
            definition: {
              actions: {
                baseBlob: {
                  delete: {
                    daysAfterModificationGreaterThan: 90
                  }
                  tierToCool: {
                    daysAfterModificationGreaterThan: 1
                  }
                  tierToArchive: {
                    daysAfterLastTierChangeGreaterThan: 7
                    daysAfterModificationGreaterThan: 30
                  }
                }
              }
              filters: {
                blobTypes: [
                  'blockBlob'
                ]
              }
            }
            enabled: true
            name: 'ArchivingPolicyBlob'
            type: 'Lifecycle'
          }
        ]
      }
    }
  } 
}

// Outputs
output stId string = storageAccount.id
output stBlobServicesId string = storageAccount::blobServices.id
