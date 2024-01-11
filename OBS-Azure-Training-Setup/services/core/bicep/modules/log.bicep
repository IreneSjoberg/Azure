@description('The region that will be used for the deployed resources.')
param location string

@description('Name of the log analytics workspace to be deployed.')
param logName string

@description('Tags that will be added on the deployed resources.')
param tags object = {}

// Deploy Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Outputs
output logId string = logAnalyticsWorkspace.id
