@secure()
param bastionname string
param vnetId string
param bastionsubnetid string = '${vnetId}/subnets/AzureBastionSubnet'


resource bastionPip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${bastionname}-pip'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: bastionname
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    enableIpConnect: true
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: bastionsubnetid
          }
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', '${bastionname}-pip')
          }
        }
      }
    ]
  }
}
