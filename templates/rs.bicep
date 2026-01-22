param location string = resourceGroup().location
param c8k10asn int
param c8k10privateIPv4 string
param c8k20asn int
param c8k20privateIPv4 string
param arssubnetId string
param prefixId string
param arsIP1 string 
param arsIP2 string

resource arsPubIp 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: 'ars-pip'
  location: location
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

resource ars 'Microsoft.Network/virtualHubs@2021-02-01' = {
  name: 'ars'
  location: location
  properties: {
    sku: 'Standard'
    allowBranchToBranchTraffic: true
    virtualRouterIps: [
      arsIP1
      arsIP2
    ]
  }
}
resource rsIpConfig 'Microsoft.Network/virtualHubs/ipConfigurations@2021-02-01' ={
  name: 'rsIpConfig'
  parent: ars
  dependsOn: [
  ]
  properties:{
    subnet:{
      id: arssubnetId
    }
    publicIPAddress: {
      id: arsPubIp.id
    }

  }
}
resource c8k1BgpConn 'Microsoft.Network/virtualHubs/bgpConnections@2021-02-01' = {
  name: 'c8k1BgpConn'
  dependsOn: [
    rsIpConfig
    c8k2BgpConn
  ]
  parent: ars

  properties: {
    peerAsn: c8k10asn
    peerIp: c8k10privateIPv4
  }
}
resource c8k2BgpConn 'Microsoft.Network/virtualHubs/bgpConnections@2021-02-01' = {
  name: 'c8k2BgpConn'
  dependsOn: [
    rsIpConfig
  ]
  parent: ars

  properties: {
    peerAsn: c8k20asn
    peerIp: c8k20privateIPv4
  }
}

