// Parameters
param storageAccountId string
param rsvId string

// Protection Container
resource protectionContainer 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers@2023-04-01' = {
  name: '${split(rsvId, '/')[8]}/Azure/storagecontainer;Storage;${resourceGroup().name};${split(storageAccountId, '/')[8]}'
  properties: {
    backupManagementType: 'AzureStorage'
    containerType: 'StorageContainer'
    sourceResourceId: storageAccountId 
  }
}

// Outputs
output protectionContainerId string = protectionContainer.id
