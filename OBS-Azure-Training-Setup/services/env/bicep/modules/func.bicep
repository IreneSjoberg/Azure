@description('The region that will be used for the deployed resources.')
param location string

@description('Name of the function app to be deployed.')
param functionAppName string

@description('Resource ID of the subnet that the function app will used for virtual network integration.')
param functionAppSubnetId string

@description('Resource ID of the storage account where the function app will keep content.')
param storageAccountId string

@description('Resource ID of the workspaec that we will be sending logs to.')
param workspaceId string

@description('Network CIDRs that will be allowed to connect to restricted resources.')
param allowedNetworkCidrs array = []

@description('Tags that will be added on the deployed resources.')
param tags object = {}

// Variables
var storageAccountContributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Storage Account Contributor role

// Get existing storage account
resource storageAccountExisting 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: split(storageAccountId, '/')[8]
}

// Deploy Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${functionAppName}-appi'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: workspaceId
  }
}

// Deploy App Service Plan
resource functionAppServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${functionAppName}-asp'
  location: location
  tags: tags
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  kind: 'functionapp'
}

// Deploy Function App
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'functionapp'
  properties: {
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    serverFarmId: functionAppServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountExisting.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccountExisting.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'ResourceGroupName'
          value: split(storageAccountExisting.id, '/')[4]
        }
        {
          name: 'StorageAccountName'
          value: storageAccountExisting.name
        }
      ]
      functionAppScaleLimit: 3
      http20Enabled: true
      ipSecurityRestrictionsDefaultAction: 'Allow'
      minTlsVersion: '1.2'
      powerShellVersion: '7.2'
      scmIpSecurityRestrictions: [for (cidr, i) in allowedNetworkCidrs: {
        action: 'Allow'
        description: 'Allow ${cidr}'
        ipAddress: cidr
        name: 'Allow-CIDR-${100 + i}'
        priority: 100 + i
      }]
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
    }
    virtualNetworkSubnetId: functionAppSubnetId
    vnetContentShareEnabled: true
  }

  // Deploy Fileshare Function
  resource fileshareFunction 'functions' = {
    name: 'fileshare-function'
    properties: {
      config: {
        bindings: [
          {
            type: 'httpTrigger'
            direction: 'in'
            name: 'HttpRequest'
            authLevel: 'function'
            methods: ['post']
          }
          {
            type: 'http'
            direction: 'out'
            name: 'HttpResponse'
          }
          {
            type: 'table'
            direction: 'out'
            name: 'StorageAccountTable'
            tableName: 'FileShareOrders'
            connection: 'AzureWebJobsStorage'
          }
        ]
      }
      files: {
        'run.ps1': loadTextContent('../../functions/fileshare/run-fileshare.ps1')
        '../requirements.psd1': loadTextContent('../../functions/fileshare/requirements.psd1') // Do not add this to any more functions than 1 in total in function app
      }
      language: 'powershell'
    }
  }

  // Deploy SFTP Function
  resource sftpFunction 'functions' = {
    name: 'sftp-function'
    properties: {
      config: {
        bindings: [
          {
            type: 'httpTrigger'
            direction: 'in'
            name: 'HttpRequest'
            authLevel: 'function'
            methods: ['post']
          }
          {
            type: 'http'
            direction: 'out'
            name: 'HttpResponse'
          }
          {
            type: 'table'
            direction: 'out'
            name: 'StorageAccountTable'
            tableName: 'SFTPOrders'
            connection: 'AzureWebJobsStorage'
          }
        ]
      }
      files: {
        'run.ps1': loadTextContent('../../functions/sftp/run-sftp.ps1')
      }
      language: 'powershell'
    }
  }
}

// Role assignment for function app identity on the storage account
resource storageAccountRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountExisting.id, functionApp.id, storageAccountContributor)
  scope: storageAccountExisting
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageAccountContributor)
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output appiId string = applicationInsights.id
output funcPlanId string = functionAppServicePlan.id
output funcId string = functionApp.id
output funcPrincipalId string = functionApp.identity.principalId

