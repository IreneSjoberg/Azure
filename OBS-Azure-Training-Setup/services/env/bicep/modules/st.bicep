@description('The region that will be used for the deployed resources.')
param location string

@description('Name of the storage account that will be deployed.')
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
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    defaultToOAuthAuthentication: true
    isHnsEnabled: true
    isSftpEnabled: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }

  // Get blobServices
  resource blobServices 'blobServices' existing = {
    name: 'default'
  }

  // Get fileServices
  resource fileServices 'fileServices' = {
    name: 'default'
    properties: {
      protocolSettings: {
        smb: {
          authenticationMethods: 'NTLMv2;Kerberos'
          channelEncryption: 'AES-128-CCM;AES-128-GCM;AES-256-GCM'
          kerberosTicketEncryption: 'RC4-HMAC;AES-256'
          versions: 'SMB3.0;SMB3.1.1'
        }
      }
    }
  }

  // Get tableServices
  resource tableServices 'tableServices' existing = {
    name: 'default'

    // Deploy tables
    resource fileshareTable 'tables' = {
      name: 'FileShareOrders'
    }

    resource sftpTable 'tables' = {
      name: 'SFTPOrders'
    }
  }
}

// Outputs
output stId string = storageAccount.id
output stBlobServicesId string = storageAccount::blobServices.id
output stFileServicesId string = storageAccount::fileServices.id
output stTableServicesId string = storageAccount::tableServices.id
