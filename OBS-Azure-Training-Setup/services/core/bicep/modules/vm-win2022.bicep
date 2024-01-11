@description('The region that will be used for the deployed resources.')
param location string

@description('Name of the VM to be deployed.')
@minLength(3)
@maxLength(15)
param vmName string

@description('Subnet ID of the subnet that the VM will get the private IP address from.')
param vmSubnetId string

@description('The virtual machine SKU that will be used for the deployed VM.')
param vmSize string = 'Standard_B2s'

@description('The password that will be used for the administrator/root account of the VM.')
@secure()
param adminPassword string

@description('The username that will be used for the administrator/root account of the VM.')
param adminUsername string = 'azure-admin'

@description('Tags that will be added on the deployed resources.')
param tags object = {}

// Variables
var pipName = '${vmName}-pip'
var nicName = '${vmName}-nic'

// Deploy Public IP
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: pipName
  location: location
  tags: tags
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

// Deploy NIC
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-06-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: vmSubnetId
          }
        }
      }
    ]
  }
}

// Deploy VM
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      adminPassword: adminPassword
      adminUsername: adminUsername
      computerName: vmName
    }
    securityProfile: {
      encryptionAtHost: true
    }
    storageProfile: {
      osDisk: {
      createOption:  'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        name: '${vmName}-osdisk'
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

// Outputs
output pipId string = publicIp.id
output nicId string = networkInterface.id
output vmId string = virtualMachine.id
output vmPublicIp string = publicIp.properties.ipAddress
output vmPrivateIp string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress
