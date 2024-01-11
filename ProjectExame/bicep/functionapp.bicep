// Parameters
@description('Region for the deployed resources.')
param location string

@description('Resource ID of the storage account where the logs will be archived.')
param archiveId string

@description('Resource ID of the log analytic workspace to which logs will be sent.')
param logAnalyticsWorkspaceId string

@description('Resource ID of the subnet dedicated for function app outbound traffic.')
param funcSnetId string

@description('Resource ID of the vnet where where the function app resources will be deployed.')
param vnetId string

@description('Resource ID of the storage account where created filshares and blobcontainers will end up.')
param storageAccountId string

param appName string

// Variables
var functionAppName = appName
var hostingPlanName = appName
var fileshareTable = 'FileshareOrders'
var SFTPTable = 'SFTPOrders'
var storageAccountContributor = '17d1049b-9a84-46fb-8f53-869881c3d3ab'

// Storage Account
resource storageAccountExisting 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: split(storageAccountId, '/')[8]
}

// Application insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${appName}-appi'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    RetentionInDays: 30
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Diagnostic Settings
resource appInsightsDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appInsights.name}-diag'
  scope: appInsights
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: archiveId
    logs: [
      {
        enabled: true
        categoryGroup: 'allLogs'
      }
    ]
  }
}

// Function App
resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'EP1'
    tier: 'ElasticPremium'
  }
  kind: 'functionapp'
}

resource funcApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountExisting.name};AccountKey=${listKeys(storageAccountExisting.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountExisting.name};AccountKey=${listKeys(storageAccountExisting.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'Website_MAX_DYNAMIC_APPLICATION_SCALE_OUT'
          value: '3'
        }
        {
          name: 'StorageAccountName'
          value: storageAccountExisting.name
        }
        {
          name: 'ResourceGroupName'
          value: resourceGroup().name
        }
        {
          name: 'FileshareTable'
          value: fileshareTable
        }
        {
          name: 'SFTPTable'
          value: SFTPTable
        }
      ]
      scmIpSecurityRestrictions: [
        {
          action: 'Deny'
          ipAddress: '10.0.1.5/32'
          name: 'InternalNetworkRule'
          priority: 100
        }
        {
          action: 'Allow'
          ipAddress: '217.213.76.27/32'
          name: 'ForDevelopmentPurpose'
          priority: 200
        }
      ]
      scmIpSecurityRestrictionsDefaultAction: 'Allow'
      vnetName: split(vnetId, '/')[8]
    }
    clientAffinityEnabled: false
    virtualNetworkSubnetId: funcSnetId
    publicNetworkAccess: 'Enabled'
    httpsOnly: true
  }

  // Fileshare Function
  resource fileshareFunc 'functions' = {
    name: 'fileshare-func'
    properties: {
      config: {
        bindings: [
          {
            type: 'httpTrigger'
            direction: 'in'
            name: 'Request'
            authLevel: 'function'
            methods: ['post']
          }
          {
            type: 'http'
            direction: 'out'
            name: 'Response'
          }
          {
            type: 'table'
            direction: 'out'
            name: 'tableOutput'
            tableName: fileshareTable
            connection: 'AzureWebJobsStorage'
          }
        ]
      }
      files: {
        'run.ps1': loadTextContent('../functions/fileshare-func/run.ps1')
        '../requirements.psd1': loadTextContent('../functions/fileshare-func/requirements.psd1')
      }
      language: 'powershell'
    }
  }

  // SFTP Function
  resource SFTPFunc 'functions' = {
    name: 'SFTP-func'
    properties: {
      config: {
        bindings: [
          {
            type: 'httpTrigger'
            direction: 'in'
            name: 'Request'
            authLevel: 'function'
            methods: ['post']
          }
          {
            type: 'http'
            direction: 'out'
            name: 'Response'
          }
          {
            type: 'table'
            direction: 'out'
            name: 'tableOutput'
            tableName: SFTPTable
            connection: 'AzureWebJobsStorage'
          }
        ]
      }
      files: {
        'run.ps1': loadTextContent('../functions/SFTP-func/run.ps1')
      }
      language: 'powershell'
    }
  }
}

// Role Assignment
resource storageAccountRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(funcApp.name, 'storageAccountContributor', '1.0')
  scope: storageAccountExisting
  properties: {
    principalId: funcApp.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageAccountContributor)
    principalType: 'ServicePrincipal'
  }
}

// Diagnostic settings
resource funcAppDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${funcApp.name}-diag'
  scope: funcApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: archiveId
    logs: [
      {
        enabled: true
        category: 'FunctionAppLogs'
      }
    ]
  }
}

// Outputs
output appiId string = appInsights.id
output funcId string = funcApp.id
output fileshareFuncId string = funcApp::fileshareFunc.id
output SFTPFuncId string = funcApp::SFTPFunc.id
