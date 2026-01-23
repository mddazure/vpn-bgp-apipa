param remotepubip string
param lngname string
param localbgpasn int = 65002
param c8kApipa1 string
param c8kApipa2 string

resource lng 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: lngname
  location: resourceGroup().location
  properties: {
    gatewayIpAddress: remotepubip
    bgpSettings: {
      asn: localbgpasn
      bgpPeeringAddresses: [
        {
          customBgpIpAddress: c8kApipa1
        }
        {
          customBgpIpAddress: c8kApipa2
        }
      ]
    }
  }
} 
output lngid string = lng.id
