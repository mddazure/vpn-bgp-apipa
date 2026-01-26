param vnetname string
param vnetIPrange string
param outsideSubnetIPrange string
param insideSubnetIPrange string
param vmSubnetIPrange string
param gwSubnetIPrange string = ''
param arsSubnetIPrange string = ''
param bastionSubnetIPrange string = ''
param pip1Name string
param pip2Name string
param pip3Name string = ''
param pip4Name string = ''
param prefixId string

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetname
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetIPrange
      ]
    }
  }
}
resource outsideSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'outside'
  properties: {
    addressPrefix: outsideSubnetIPrange
  }
}
resource insideSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'inside'
  dependsOn: [
    outsideSubnet
  ]
  properties: {
    addressPrefix: insideSubnetIPrange
  }
}
resource vmSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  dependsOn: [
    insideSubnet
  ]
  name: 'vm'
  properties: {
    addressPrefix: vmSubnetIPrange
  }
}
resource gwSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (gwSubnetIPrange != '') {
  parent: vnet
  dependsOn: [
    vmSubnet
  ]
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: gwSubnetIPrange
  }
}
resource arsSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (arsSubnetIPrange != '') {
  parent: vnet
  dependsOn: [
    vmSubnet
  ]
  name: 'RouteServerSubnet'
  properties: {
    addressPrefix: arsSubnetIPrange
  }
}
resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (bastionSubnetIPrange != '') { 
  parent: vnet
  dependsOn: [
    vmSubnet
  ]
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: bastionSubnetIPrange
  }
}

resource pubip1 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: pip1Name
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'    
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
  publicIPPrefix: {
      id: prefixId
    }
   publicIPAllocationMethod: 'Static'
   publicIPAddressVersion: 'IPv4'
  }
}
resource pubip2 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: pip2Name
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'    
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
  publicIPPrefix: {
      id: prefixId
    }
   publicIPAllocationMethod: 'Static'
   publicIPAddressVersion: 'IPv4'
  }
}
resource pubip3 'Microsoft.Network/publicIPAddresses@2020-11-01' = if (pip3Name != '') {
  name: pip3Name
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'    
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
  publicIPPrefix: {
      id: prefixId
    }
   publicIPAllocationMethod: 'Static'
   publicIPAddressVersion: 'IPv4'
  }
}
resource pubip4 'Microsoft.Network/publicIPAddresses@2020-11-01' = if (pip4Name != '') {
  name: pip4Name
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Regional'    
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
  publicIPPrefix: {
      id: prefixId
    }
   publicIPAllocationMethod: 'Static'
   publicIPAddressVersion: 'IPv4'
  }
}
output vnetName string = vnet.name
output vnetId string = vnet.id
output outsideSubnetId string = outsideSubnet.id
output insideSubnetId string = insideSubnet.id
output vmSubnetId string = vmSubnet.id
output gwSubnetId string = gwSubnetIPrange != '' ? gwSubnet.id : ''
output arsSubnetId string = arsSubnetIPrange != '' ? arsSubnet.id : ''
output bastionSubnetId string = bastionSubnetIPrange != '' ? bastionSubnet.id : ''
output pubIp1 string = pubip1.properties.ipAddress
output pubip1Id string = pubip1.id
output pubIp2 string = pubip2.properties.ipAddress
output pubip2Id string = pubip2.id
output pubIp3 string = pip3Name != '' ? pubip3.properties.ipAddress : ''
output pubip3Id string = pip3Name != '' ? pubip3.id : ''
output pubIp4 string = pip4Name != '' ? pubip4.properties.ipAddress : ''
output pubip4Id string = pip4Name != '' ? pubip4.id : ''
