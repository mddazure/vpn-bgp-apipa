param vmname string
param subnetId string
param adminUsername string
param vmprivateip string = ''
param vmpublicipid string = ''
param adminPassword string

resource nic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${vmname}-nic'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: empty(vmprivateip) ? 'Dynamic' : 'Static'
          privateIPAddress: empty(vmprivateip) ? null : vmprivateip
          publicIPAddress: empty(vmpublicipid) ? null : {
            id: vmpublicipid
          }
        }
      }
    ]
  }
}
resource vm 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: vmname
  location: resourceGroup().location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2as_v5'
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: vmname
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}
