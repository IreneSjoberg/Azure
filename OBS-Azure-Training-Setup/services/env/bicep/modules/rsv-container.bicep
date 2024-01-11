@description('Resource ID of the Recovery Services Vault.')
param recoveryServicesVaultId string

@description('Resource ID of the storage account that will be registered as a protection container for the Recovery Services Vault.')
param storageAccountId string

// Register storage account as a backup container in RSV
resource protectionContainer 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers@2023-06-01' = {
  name: '${split(recoveryServicesVaultId, '/')[8]}/Azure/storagecontainer;Storage;${split(storageAccountId, '/')[4]};${split(storageAccountId, '/')[8]}'
  properties: {
    backupManagementType: 'AzureStorage'
    containerType: 'StorageContainer'
    sourceResourceId: storageAccountId
  }
}

// Outputs
output rsvProtectionContainerId string = protectionContainer.id
