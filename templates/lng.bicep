param remotepubip string
param lngname string
param localbgpasn int = 65001
param remotebgpasn int = 65002
param localapiparange string
param remoteapipa string
param vpnkey string

resource lng 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: lngname
  location: resourceGroup().location
  properties: {
    gatewayIpAddress: remotepubip
    localNetworkAddressSpace: {
      addressPrefixes: [
        localapiparange
      ]
    }
    bgpSettings: {
      asn: remotebgpasn
      bgpPeeringAddress: remoteapipa
    }
  }
} 
output lngid string = lng.id
