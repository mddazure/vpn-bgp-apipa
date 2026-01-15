param vnetgwid string
param lngid string
param key string
param connectionname string
param custombgpip string

resource connection 'Microsoft.Network/connections@2024-05-01' = {
  name: connectionname
  location: resourceGroup().location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: {
      properties: {}
      id: vnetgwid
      }
    localNetworkGateway2: {
      properties: {}
      id: lngid
    }
    routingWeight: 10
    sharedKey: key
    enableBgp: true
    ipsecPolicies:[
      {
        saLifeTimeSeconds: 28800
        saDataSizeKilobytes: 102400000
        ipsecEncryption: 'AES256'
        ipsecIntegrity: 'SHA256'
        ikeEncryption: 'AES256'
        ikeIntegrity: 'SHA256'
        dhGroup: 'DHGroup14'
        pfsGroup: 'None'
      }
    ]
  }
}
