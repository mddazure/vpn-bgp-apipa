param ck8name string
param vnetname string
param insideSubnetid string
param outsideSubnetid string
param insideIP string
param outsideIP string
param pubIpId string
param adminUsername string
param adminPassword string
param nsGId string


resource insidenic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${ck8name}-insidenic'
  location: resourceGroup().location
  properties: {
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: insideSubnetid
          }
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: insideIP
        }
      }
    ]
  }
}
resource outsidenic 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: '${ck8name}-outsidenic'
  location: resourceGroup().location
  properties: {
    enableIPForwarding: true
    networkSecurityGroup: {
      id: nsGId
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: outsideSubnetid
          }
          publicIPAddress: {
            id: pubIpId
          }
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: outsideIP
        }
      }
    ]
  }
}
resource ck8 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: ck8name
  location: resourceGroup().location
  plan: {
    publisher: 'cisco'
    name: '17_15_01a-byol'
    product: 'cisco-c8000v-byol'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2as_v5'
    }
    storageProfile: {
      imageReference: {
        publisher: 'cisco'
        offer: 'cisco-c8000v-byol'
        sku: '17_15_01a-byol'
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
      computerName: ck8name
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: insidenic.id
          properties: {
            primary: false
          }
        }
        {
          id: outsidenic.id
          properties: {
            primary: true
          }
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

