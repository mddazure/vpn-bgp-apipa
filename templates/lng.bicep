param remotepubip string
param lngname string
param localbgpasn int = 65002
param c8kApipa string

resource lng 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: lngname
  location: resourceGroup().location
  properties: {
    gatewayIpAddress: remotepubip
    bgpSettings: {
      asn: localbgpasn
      bgpPeeringAddress: c8kApipa
    }
  }
} 
output lngid string = lng.id
