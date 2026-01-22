param remotepubip string
param lngname string
param gwbgpasn int = 65001
param localbgpasn int = 65002
param localapipa1 string
param localapipa2 string
param localbgppeeringaddress string
param vpnkey string

resource lng 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: lngname
  location: resourceGroup().location
  properties: {
    gatewayIpAddress: remotepubip
    localNetworkAddressSpace: {
      addressPrefixes: [
        localapipa1
        localapipa2
      ]
    }
    bgpSettings: {
      asn: gwbgpasn
      bgpPeeringAddress: localbgppeeringaddress
    }
  }
} 
output lngid string = lng.id
