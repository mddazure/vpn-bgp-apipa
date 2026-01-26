param vmname string
param subnetId string
param adminUsername string
param adminPassword string
param vmprivateip string = ''

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
        }
      }
    ]
  }
}
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmname
  location: resourceGroup().location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2as_v5'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
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
resource iisext 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: vm
  // The parent property is used to specify the parent resource of the extension.
  name: 'iisext'
  location: resourceGroup().location
  properties:{
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: false
    protectedSettings:{}
    settings: {
        commandToExecute: 'powershell -ExecutionPolicy Unrestricted Add-WindowsFeature Web-Server; powershell -ExecutionPolicy Unrestricted Add-Content -Path "C:\\inetpub\\wwwroot\\Default.htm" -Value $($env:computername)'
    }
  }  
}
