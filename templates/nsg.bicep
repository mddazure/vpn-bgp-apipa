param customerPip1 string
param customerPip2 string
param providerPip1 string
param providerPip2 string

resource nsg  'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'outsidensg'
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'Allow-VPN-in'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefixes: [
            customerPip1
            customerPip2
            providerPip1
            providerPip2
          ]                 
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
output nsgId string = nsg.id
