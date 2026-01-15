param location string = 'swedencentral'
param rgname string = 'vpn-bgp-apipa-lab-rg'
param customerVnetName string = 'client-Vnet'
param customerVnetIPrange string = '10.0.0.0/16'
param customerOutsideSubnetIPrange string = '10.0.0.0/24'
param customerInsideSubnetIPrange string = '10.0.1.0/24'
param customerVmSubnetIPrange string = '10.0.2.0/24'
param customerGwSubnetIPrange string = '10.0.3.0/24'
param customerVmName string = 'client-Vm'
param clientWeb1Name string = 'client-Web1'
param clientWeb2Name string = 'client-Web2'
param customerVNETGWName string = 'client-Vnet-gw'
param customerPip1Name string = 'gw-1-pip'
param customerPip2Name string = 'gw-2-pip'
param providerVnetName string = 'provider-Vnet'
param providerVnetIPrange string = '10.10.0.0/16'
param providerOutsideSubnetIPrange string = '10.10.0.0/24'
param providerInsideSubnetIPrange string = '10.10.1.0/24'
param providerVmSubnetIPrange string = '10.10.2.0/24'
param providerVmName string = 'provider-Vm'
param providerC8k1Name string = 'c8k-10'
param providerC8k2Name string = 'c8k-20'
param providerPip1Name string = 'c8k-1-pip'
param providerPip2Name string = 'c8k-2-pip'

param lng11Name string = 'lng-11'
param gw11Apiparange string = '169.254.21.0/30'
param c8k1Apipa1 string = '169.254.21.1'
param lng12Name string = 'lng-12'
param gw12Apiparange string = '169.254.22.0/30'
param c8k1Apipa2 string = '169.254.22.1'
param lng21Name string = 'lng-21'
param gw21Apiparange string = '169.254.21.4/30'
param c8k2Apipa1 string = '169.254.21.5'
param lng22Name string = 'lng-22'
param gw22Apiparange string = '169.254.22.4/30'
param c8k2Apipa2 string = '169.254.22.5'

param adminUsername string = 'AzureAdmin'
@secure()
param adminPassword string = 'vpn@123456'
@secure()
param vpnkey string = 'vpnkey123'

targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgname
  location: location
}

module prefix 'prefix.bicep' = {
  name: 'prefix'
  scope: rg
}
module customerVnet 'vnet.bicep' = {
  name: 'customerVnet'
  scope: rg
  params: {
    vnetname: customerVnetName
    vnetIPrange: customerVnetIPrange
    outsideSubnetIPrange: customerOutsideSubnetIPrange
    insideSubnetIPrange: customerInsideSubnetIPrange
    vmSubnetIPrange: customerVmSubnetIPrange
    gwSubnetIPrange: customerGwSubnetIPrange
    prefixId: prefix.outputs.prefixId
    pip1Name: customerPip1Name
    pip2Name: customerPip2Name
  }
}
module providerVnet 'vnet.bicep' = {
  name: 'providerVnet'
  scope: rg
  params: {
    vnetname: providerVnetName
    vnetIPrange: providerVnetIPrange
    outsideSubnetIPrange: providerOutsideSubnetIPrange
    insideSubnetIPrange: providerInsideSubnetIPrange
    vmSubnetIPrange: providerVmSubnetIPrange
    pip1Name: providerPip1Name
    pip2Name: providerPip2Name
    prefixId: prefix.outputs.prefixId
  }
}
module outsideNsg 'nsg.bicep' = {
  name: 'outsideNsg'
  scope: rg
  params: {
    customerPip1: customerVnet.outputs.pubIp1
    customerPip2: customerVnet.outputs.pubIp2
    providerPip1: providerVnet.outputs.pubIp1
    providerPip2: providerVnet.outputs.pubIp2
  }
}
module customerVm 'vm.bicep' = {
  name: 'customerVm'
  scope: rg
  params: {
    vmname: customerVmName
    subnetId: customerVnet.outputs.vmSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module clientWeb1 'vm-web.bicep' = {
  name: 'clientWeb1'
  scope: rg
  dependsOn: [
    customerVm
  ]
  params: {
    vmname: clientWeb1Name
    subnetId: customerVnet.outputs.vmSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module clientWeb2 'vm-web.bicep' = {
  name: 'clientWeb2'
  scope: rg
  dependsOn: [
    clientWeb1
  ]
  params: {
    vmname: clientWeb2Name
    subnetId: customerVnet.outputs.vmSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module providerVm 'vm.bicep' = {
  name: 'providerVm'
  scope: rg
  params: {
    vmname: providerVmName
    subnetId: providerVnet.outputs.vmSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

module providerC8k1 'c8k.bicep' = {
  name: 'providerC8k-1'
  scope: rg
  params: {
    ck8name: providerC8k1Name
    vnetname: providerVnet.outputs.vnetId
    insideSubnetid: providerVnet.outputs.insideSubnetId
    outsideSubnetid: providerVnet.outputs.outsideSubnetId
    nsGId: outsideNsg.outputs.nsgId
    pubIpId: providerVnet.outputs.pubip1Id
    udrName: providerVnet.outputs.udrName
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module providerC8k2 'c8k.bicep' = {
  name: 'providerC8k-2'
  scope: rg
  params: {
    ck8name: providerC8k2Name
    vnetname: providerVnet.outputs.vnetId
    insideSubnetid: providerVnet.outputs.insideSubnetId
    outsideSubnetid: providerVnet.outputs.outsideSubnetId
    nsGId: outsideNsg.outputs.nsgId
    pubIpId: providerVnet.outputs.pubip2Id
    udrName: providerVnet.outputs.udrName
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
module clientgw 'gw.bicep' = {
  name: 'clientgw'
  scope: rg
  params: {
  customerVNETGWName: customerVNETGWName
  customerPip1Id: customerVnet.outputs.pubip1Id
  customerPip2Id: customerVnet.outputs.pubip2Id
  customerVnetId: customerVnet.outputs.vnetId  
  }
}
module lng11 'lng.bicep' ={
  name: 'lng11'
  scope: rg   
  params: {
    lngname: lng11Name
    localapiparange: gw11Apiparange
    remoteapipa: c8k1Apipa1
    remotepubip: providerVnet.outputs.pubIp1
    vpnkey: vpnkey
  }
}
module lng12 'lng.bicep' ={
  name: 'lng12'
  scope: rg   
  params: {
    lngname: lng12Name
    localapiparange: gw12Apiparange
    remoteapipa: c8k1Apipa2
    remotepubip: providerVnet.outputs.pubIp1
    vpnkey: vpnkey
  }
}
module lng21 'lng.bicep' ={
  name: 'lng21'
  scope: rg   
  params: {
    lngname: lng21Name
    localapiparange: gw21Apiparange
    remoteapipa: c8k2Apipa1
    remotepubip: providerVnet.outputs.pubIp2
    vpnkey: vpnkey
  }
}
module lng22 'lng.bicep' ={
  name: 'lng22'
  scope: rg   
  params: {
    lngname: lng22Name
    localapiparange: gw22Apiparange
    remoteapipa: c8k2Apipa2
    remotepubip: providerVnet.outputs.pubIp2
    vpnkey: vpnkey
  }
}
module con11 'connection.bicep' ={
  name: 'con11'
  scope: rg   
  params: {
    connectionname: 'con-11'
    vnetgwid: clientgw.outputs.vnetgwId
    lngid: lng11.outputs.lngid
    key: vpnkey
    custombgpip: c8k1Apipa1
  }
}
module con12 'connection.bicep' ={
  name: 'con12'
  scope: rg   
  params: {
    connectionname: 'con-12'
    vnetgwid: clientgw.outputs.vnetgwId
    lngid: lng12.outputs.lngid
    key: vpnkey
    custombgpip: c8k1Apipa2
  }
}
module con21 'connection.bicep' ={
  name: 'con21'
  scope: rg   
  params: {
    connectionname: 'con-21'
    vnetgwid: clientgw.outputs.vnetgwId
    lngid: lng21.outputs.lngid
    key: vpnkey
    custombgpip: c8k2Apipa1
  }
}
module con22 'connection.bicep' ={
  name: 'con22'
  scope: rg   
  params: {
    connectionname: 'con-22'
    vnetgwid: clientgw.outputs.vnetgwId
    lngid: lng22.outputs.lngid
    key: vpnkey
    custombgpip: c8k2Apipa2
  }
}
