// Parameters
@description('Region for the deployed resources.')
param location string

param logWorkspace string 

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logWorkspace
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Outputs
output logId string = logAnalyticsWorkspace.id
