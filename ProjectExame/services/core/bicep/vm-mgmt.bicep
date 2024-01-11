// Parameters
@description ('Location for all resources.')
param location string = resourceGroup().location

@description ('Login for VM')
param vmAdminUser string = 'theazures'
@secure()
param vmAdminPassword string

@description('Resource Names.')
param vmName string

@description('Resource Ids.')
param subnetId string 
param storageAccountId string
param logAnalyticsWorkspaceId string

// Public IP
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: '${vmName}-pip'
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

// Networkinterface
resource nic 'Microsoft.Network/networkInterfaces@2023-06-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

// Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUser
      adminPassword: vmAdminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    storageProfile: {
      osDisk: {
        osType: 'Windows'
        name: '${vmName}OsDisk'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition-hotpatch'
        version: 'latest'
      }
    }
  }
}

// Diagnostic settings
resource vmPipDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${vmName}-diag'
  scope: publicIP
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: storageAccountId
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
