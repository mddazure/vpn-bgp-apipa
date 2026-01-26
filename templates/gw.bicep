param customerVNETGWName string
param customerPip1Id string
param customerPip2Id string
param customerVnetId string
param instance0Apipa1 string
param instance1Apipa1 string
param instance0Apipa2 string
param instance1Apipa2 string

resource vnetgw 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: customerVNETGWName
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'vnetgwconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${customerVnetId}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: customerPip1Id
          }
        }
      }
      {
        name: 'vnetgwconfig2'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${customerVnetId}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: customerPip2Id
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: true
    bgpSettings: {
      asn: 65001
      bgpPeeringAddresses: [
        {
          ipconfigurationId: '${az.resourceId('Microsoft.Network/virtualNetworkGateways', customerVNETGWName)}/ipConfigurations/vnetgwconfig'
          customBgpIpAddresses: [
            instance0Apipa1  // Instance 0: used by both c8k-10 and c8k-20 Tunnel101
            instance0Apipa2  // Instance 0: used by both c8k-10 and c8k-20 Tunnel201
          ]
        }
        {
          ipconfigurationId: '${az.resourceId('Microsoft.Network/virtualNetworkGateways', customerVNETGWName)}/ipConfigurations/vnetgwconfig2'
          customBgpIpAddresses: [
            instance1Apipa1  // Instance 1: used by both c8k-10 and c8k-20 Tunnel102
            instance1Apipa2  // Instance 1: used by both c8k-10 and c8k-20 Tunnel202
          ]
        }
      ]
    }
    activeActive: true
    sku: {
      name: 'VpnGw1Az'
      tier: 'VpnGw1AZ'
    }
  }
}
output vnetgwId string = vnetgw.id
output vnetgwIp1 string = vnetgw.properties.ipConfigurations[0].properties.publicIPAddress.id
output vnetgwIp2 string = vnetgw.properties.ipConfigurations[1].properties.publicIPAddress.id


