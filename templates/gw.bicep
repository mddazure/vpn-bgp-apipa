param customerVNETGWName string
param customerPip1Id string
param customerPip2Id string
param customerVnetId string

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
            '169.254.21.2'
            '169.254.22.2'
          ]
        }
                {
          ipconfigurationId: '${az.resourceId('Microsoft.Network/virtualNetworkGateways', customerVNETGWName)}/ipConfigurations/vnetgwconfig2'
          customBgpIpAddresses: [
            '169.254.21.6'
            '169.254.22.6'
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


