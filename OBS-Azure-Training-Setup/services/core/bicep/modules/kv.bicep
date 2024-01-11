@description('The region that will be used for the deployed resources.')
param location string

@description('Name of the VM to be deployed.')
param kvName string

@description('Secrets to be created for the deployed keyvault.')
param kvSecrets array = []

@description('Tags that will be added on the deployed resources.')
param tags object = {}

// Deploy KV
resource keyvault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enableSoftDelete: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'Disabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
  }

  // Deploy KV secrets
  resource kvSecret 'secrets' = [for secret in kvSecrets: {
    name: secret.name
    properties: {
      value: secret.value
    }
  }]
}

// Outputs
output kvId string = keyvault.id
output kvName string = keyvault.name
