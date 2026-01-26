param location string = 'swedencentral'
param rgname string = 'vpn-bgp-apipa-lab-rg2'

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
param arsSubnetIPrange string = '10.10.4.0/24'
param arsIP1 string = '10.10.4.4'
param arsIP2 string = '10.10.4.5'

param providerVmName string = 'provider-Vm'
param providerC8k1Name string = 'c8k-10'
param providerC8k2Name string = 'c8k-20'
param providerPip1Name string = 'c8k-1-pip'
param providerPip2Name string = 'c8k-2-pip'
param c8k10asn int = 65002
param c8k20asn int = 65002
param c8k10insideIP string = '10.10.1.4'
param c8k20insideIP string = '10.10.1.5'
param c8k10outsideIP string = '10.10.0.4'
param c8k20outsideIP string = '10.10.0.5'

param c8k10Apipa string = '169.254.21.1' // loopback0 on c8k-10 = bgp neighbor update source
param c8k20Apipa string = '169.254.22.1' // loopback0 on c8k-20 = bgp neighbor update source

param instance0Apipa1 string = '169.254.21.2'  // Gateway Instance 0 IP
param instance0Apipa2 string = '169.254.22.2'  // Gateway Instance 1 IP
param instance1Apipa1 string = '169.254.21.6'  // Gateway Instance 0 IP
param instance1Apipa2 string = '169.254.22.6'  // Gateway Instance 1 IP

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
    arsSubnetIPrange: arsSubnetIPrange
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
    insideIP: c8k10insideIP
    outsideSubnetid: providerVnet.outputs.outsideSubnetId
    outsideIP: c8k10outsideIP
    nsGId: outsideNsg.outputs.nsgId
    pubIpId: providerVnet.outputs.pubip1Id
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
    insideIP: c8k20insideIP
    outsideSubnetid: providerVnet.outputs.outsideSubnetId
    outsideIP: c8k20outsideIP
    nsGId: outsideNsg.outputs.nsgId
    pubIpId: providerVnet.outputs.pubip2Id
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
module lngc8k10 'lng.bicep' ={
  name: 'lng-c8k-10'
  scope: rg   
  params: {
    lngname: 'lng-c8k-10'
    localbgpasn: c8k10asn
    c8kApipa: c8k10Apipa
    remotepubip: providerVnet.outputs.pubIp1
  }
}
module lngc8k20 'lng.bicep' ={
  name: 'lng-c8k-20'
  scope: rg   
  params: {
    lngname: 'lng-c8k-20'
    localbgpasn: c8k20asn
    c8kApipa: c8k20Apipa
    remotepubip: providerVnet.outputs.pubIp2
  }
}
module conc8k10 'connection.bicep' ={
  // connection from both instances of VPN GW to c8k-10 (represented by lngc8k10)
  name: 'con-c8k-10'
  scope: rg   
  params: {
    connectionname: 'con-c8k-10'
    vnetgwid: clientgw.outputs.vnetgwId
    lngid: lngc8k10.outputs.lngid
    key: vpnkey
    custombgpip1: instance0Apipa1
    custombgpip2: instance1Apipa1
  }
}
module conc8k20 'connection.bicep' ={
  // connection from both instances of VPN GW to c8k-20 (represented by lngc8k20)
  name: 'con-c8k-20'
  scope: rg   
  params: {
    connectionname: 'con-c8k-20'
    vnetgwid: clientgw.outputs.vnetgwId
    lngid: lngc8k20.outputs.lngid
    key: vpnkey
    custombgpip1: instance0Apipa2
    custombgpip2: instance1Apipa2
  }
}
module ars 'rs.bicep' = {
  name: 'ars'
  dependsOn:[
    providerC8k1
    providerC8k2
  ]
  scope: rg
  params: {
    c8k10asn: c8k10asn
    c8k20asn: c8k20asn
    arssubnetId: providerVnet.outputs.arsSubnetId
    prefixId: prefix.outputs.prefixId
    c8k10privateIPv4: c8k10insideIP
    c8k20privateIPv4: c8k20insideIP
    arsIP1: arsIP1
    arsIP2: arsIP2
  }
}
output clientgwvnetgwIp1 string = clientgw.outputs.vnetgwIp1
output clientgwvnetgwIp2 string = clientgw.outputs.vnetgwIp2
