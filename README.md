# VPN Gateway with BGP and APIPA Addresses

This repository demonstrates how to configure an Azure Active-Active VPN Gateway with BGP using APIPA (Automatic Private IP Addressing) custom addresses to establish a full mesh (bow-tie) connectivity with two Cisco 8000v Network Virtual Appliances (NVAs).

## Architecture Overview

```
Cisco c8k-10 (Single Public IP)          Azure VPN Gateway (Active-Active)
┌─────────────────────────────┐         ┌──────────────────────────────────┐
│ Public IP: a.a.a.a          │         │ Instance 0 (gw-1-pip)            │
│                             │─────────│  • Public IP: x.x.x.x            │
│ Tunnel101: 169.254.21.1  ───┼────────►│  • BGP IP: 169.254.21.2          │
│ Tunnel102: 169.254.22.1  ───┼────┐    │                                  │
└─────────────────────────────┘    │    │                                  │
                                   │    │ Instance 1 (gw-2-pip)            │
Cisco c8k-20 (Single Public IP)    │    │  • Public IP: y.y.y.y            │
┌─────────────────────────────┐    │    │  • BGP IP: 169.254.22.6          │
│ Public IP: b.b.b.b          │    │    │                                  │
│                             │────┼───►│                                  │
│ Tunnel101: 169.254.21.5  ───┼────┘    │                                  │
│ Tunnel102: 169.254.22.5  ───┼────────►│                                  │
└─────────────────────────────┘         └──────────────────────────────────┘

BOW-TIE TOPOLOGY:
├─ c8k-10 Tunnel101 → Azure Instance 0 (gw-1-pip)
├─ c8k-10 Tunnel102 → Azure Instance 1 (gw-2-pip)
├─ c8k-20 Tunnel101 → Azure Instance 0 (gw-1-pip)
└─ c8k-20 Tunnel102 → Azure Instance 1 (gw-2-pip)

Azure Resources:
├─ 4 Local Network Gateways (lng-11, lng-12, lng-21, lng-22)
├─ 4 Connections (con-11, con-12, con-21, con-22)
└─ 4 IPsec Tunnels (full bow-tie topology)
```

![Architecture Diagram](/images/vpn-bgp-apipa.png)

## Key Design Principles

### 1. Four LNGs for Four Tunnels (Bow-Tie Topology)

**Understanding the Bow-Tie:**

A true bow-tie (full mesh) topology means **each NVA connects to BOTH Azure VPN Gateway instances**:
- c8k-10 has one tunnel to Instance 0 AND one tunnel to Instance 1
- c8k-20 has one tunnel to Instance 0 AND one tunnel to Instance 1

This provides **full redundancy**: if any single component fails (Instance 0, Instance 1, c8k-10, or c8k-20), connectivity is maintained.

**Why 4 LNGs are Required:**

Each LNG represents **one specific tunnel** with its own:
- APIPA BGP peer address
- Tunnel destination (which Azure Gateway instance)
- Connection object

Even though lng-11 and lng-12 both point to the same NVA public IP (c8k-10), they represent **different tunnels**:
- **lng-11**: c8k-10's tunnel to Azure Instance 0 (gw-1-pip)
- **lng-12**: c8k-10's tunnel to Azure Instance 1 (gw-2-pip)

The same applies for c8k-20:
- **lng-21**: c8k-20's tunnel to Azure Instance 0 (gw-1-pip)  
- **lng-22**: c8k-20's tunnel to Azure Instance 1 (gw-2-pip)

**How Azure Allows Multiple LNGs with Same Public IP:**

Normally, Azure doesn't allow multiple connections to LNGs with the same `gatewayIpAddress`. However, when using **BGP with custom APIPA addresses**, Azure differentiates LNGs by the **combination** of:
- `gatewayIpAddress` (the public IP)
- `bgpSettings.bgpPeeringAddress` (the APIPA address)

Example:
```bicep
// These are seen as DIFFERENT LNGs by Azure:
lng-11: { gatewayIpAddress: 'a.a.a.a', bgpPeeringAddress: '169.254.21.1' }
lng-12: { gatewayIpAddress: 'a.a.a.a', bgpPeeringAddress: '169.254.22.1' }
```

This BGP peering address differentiation is what enables the bow-tie topology with single-IP NVAs.

**Key Insight:** In the Microsoft AWS article, they need 4 LNGs because AWS provides 2 public IPs per connection. In this Cisco setup, we need 4 LNGs because we're creating a bow-tie where each NVA connects to **both** Azure Gateway instances, and Azure differentiates them by their unique BGP peering addresses.

### 2. APIPA (Custom) BGP Addresses

APIPA addresses are used for BGP peering over IPsec tunnels to avoid overlapping address spaces between on-premises and Azure networks.

**Address Allocation:**

Azure reserves the APIPA range **169.254.21.0 to 169.254.22.255** for VPN Gateway BGP.

In this setup, we use four /30 subnets:

| Subnet | Usage | Azure IP | Cisco IP |
|--------|-------|----------|----------|
| 169.254.21.0/30 | c8k-10 Tunnel 1 to Azure Instance 0 | 169.254.21.2 | 169.254.21.1 |
| 169.254.22.0/30 | c8k-10 Tunnel 2 to Azure Instance 0 | 169.254.22.2 | 169.254.22.1 |
| 169.254.21.4/30 | c8k-20 Tunnel 1 to Azure Instance 1 | 169.254.21.6 | 169.254.21.5 |
| 169.254.22.4/30 | c8k-20 Tunnel 2 to Azure Instance 1 | 169.254.22.6 | 169.254.22.5 |

**Why APIPA?**
- Eliminates address space conflicts
- Provides dedicated BGP peering addresses per tunnel
- Works independently of the VPN gateway's internal BGP IP
- Allows multiple tunnels with unique BGP sessions

## BGP Session Mapping

The configuration establishes **4 BGP sessions** in a bow-tie topology:

1. **c8k-10 Tunnel101** (169.254.21.1) ↔ **Azure Instance 0** (169.254.21.2)
2. **c8k-10 Tunnel102** (169.254.22.1) ↔ **Azure Instance 1** (169.254.22.6)
3. **c8k-20 Tunnel101** (169.254.21.5) ↔ **Azure Instance 0** (169.254.21.2)
4. **c8k-20 Tunnel102** (169.254.22.5) ↔ **Azure Instance 1** (169.254.22.6)

**Redundancy:**
- Both Instance 0 sessions (from both NVAs) use the 169.254.21.0/24 range
- Both Instance 1 sessions (from both NVAs) use the 169.254.22.0/24 range
- If Instance 0 OR c8k-10 fails, sessions 2, 3, and 4 remain active
- If Instance 1 OR c8k-20 fails, sessions 1, 2, and 3 remain active

**Important BGP Details:**
- Azure VPN Gateway ASN: **65001**
- Cisco NVAs ASN: **65002**
- Azure Instance 0 has **one** custom BGP IP: 169.254.21.2 (shared by both NVAs' tunnels to Instance 0)
- Azure Instance 1 has **one** custom BGP IP: 169.254.22.6 (shared by both NVAs' tunnels to Instance 1)
- Each Cisco NVA establishes **two BGP sessions** (one to each Azure Gateway instance)

## Azure Configuration

### VPN Gateway Configuration

The Active-Active VPN Gateway is configured with:

```bicep
bgpSettings: {
  asn: 65001
  bgpPeeringAddresses: [
    {
      ipconfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig'
      customBgpIpAddresses: [
        '169.254.21.2'  // For c8k-10 Tunnel101
        '169.254.22.2'  // For c8k-10 Tunnel102
      ]
    }
    {
      ipconfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig2'
      customBgpIpAddresses: [
        '169.254.21.6'  // For c8k-20 Tunnel101
        '169.254.22.6'  // For c8k-20 Tunnel102
      ]
    }
  ]
}
```

### Local Network Gateway Configuration

Each LNG defines one BGP peer address for one tunnel:

**lng-11 (c8k-10 to Instance 0):**
```bicep
properties: {
  gatewayIpAddress: '<c8k-10-public-ip>'
  bgpSettings: {
    asn: 65002
    bgpPeeringAddress: '169.254.21.1'
  }
}
```

**lng-12 (c8k-10 to Instance 1):**
```bicep
properties: {
  gatewayIpAddress: '<c8k-10-public-ip>'  // Same IP as lng-11
  bgpSettings: {
    asn: 65002
    bgpPeeringAddress: '169.254.22.1'  // Different APIPA
  }
}
```

**lng-21 (c8k-20 to Instance 0):**
```bicep
properties: {
  gatewayIpAddress: '<c8k-20-public-ip>'
  bgpSettings: {
    asn: 65002
    bgpPeeringAddress: '169.254.21.5'
  }
}
```

**lng-22 (c8k-20 to Instance 1):**
```bicep
properties: {
  gatewayIpAddress: '<c8k-20-public-ip>'  // Same IP as lng-21
  bgpSettings: {
    asn: 65002
    bgpPeeringAddress: '169.254.22.5'  // Different APIPA
  }
}
```

### Connection Configuration

Each connection specifies which Azure Gateway instance it connects to via custom BGP IP:

**con-11 (c8k-10 to Instance 0):**
```bicep
gatewayCustomBgpIpAddresses: [
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig'
    customBgpIpAddress: '169.254.21.2'  // Instance 0
  }
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig2'
    customBgpIpAddress: '169.254.21.6'  // Not used
  }
]
```

**con-12 (c8k-10 to Instance 1):**
```bicep
gatewayCustomBgpIpAddresses: [
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig'
    customBgpIpAddress: '169.254.22.2'  // Not used
  }
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig2'
    customBgpIpAddress: '169.254.22.6'  // Instance 1
  }
]
```

**con-21 (c8k-20 to Instance 0):**
```bicep
gatewayCustomBgpIpAddresses: [
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig'
    customBgpIpAddress: '169.254.21.2'  // Instance 0
  }
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig2'
    customBgpIpAddress: '169.254.21.6'  // Not used
  }
]
```

**con-22 (c8k-20 to Instance 1):**
```bicep
gatewayCustomBgpIpAddresses: [
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig'
    customBgpIpAddress: '169.254.22.2'  // Not used
  }
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig2'
    customBgpIpAddress: '169.254.22.6'  // Instance 1
  }
]
```

**Note:** Connections to Instance 0 use the primary IP configuration, connections to Instance 1 use the secondary IP configuration. The "not used" IP must still be valid but is ignored by Azure.

## Cisco 8000v Configuration

### c8k-10 Configuration

Tunnels to **both** Azure Gateway instances (bow-tie):

```ios
interface Tunnel101
 description tunnel 1 to gw-1 (Instance 0) - 169.254.21.0/30
 ip address 169.254.21.1 255.255.255.255
 tunnel source GigabitEthernet1
 tunnel destination [gw-1-pip]
 tunnel protection ipsec profile IPSEC-PROFILE

interface Tunnel102
 description tunnel 2 to gw-2 (Instance 1) - 169.254.22.0/30
 ip address 169.254.22.1 255.255.255.255
 tunnel source GigabitEthernet1
 tunnel destination [gw-2-pip]
 tunnel protection ipsec profile IPSEC-PROFILE

router bgp 65002
 neighbor 169.254.21.2 remote-as 65001
 neighbor 169.254.21.2 update-source Tunnel101
 neighbor 169.254.22.6 remote-as 65001
 neighbor 169.254.22.6 update-source Tunnel102
```

### c8k-20 Configuration

Tunnels to **both** Azure Gateway instances (bow-tie):

```ios
interface Tunnel101
 description tunnel 1 to gw-1 (Instance 0) - 169.254.21.4/30
 ip address 169.254.21.5 255.255.255.255
 tunnel source GigabitEthernet1
 tunnel destination [gw-1-pip]
 tunnel protection ipsec profile IPSEC-PROFILE

interface Tunnel102
 description tunnel 2 to gw-2 (Instance 1) - 169.254.22.4/30
 ip address 169.254.22.5 255.255.255.255
 tunnel source GigabitEthernet1
 tunnel destination [gw-2-pip]
 tunnel protection ipsec profile IPSEC-PROFILE

router bgp 65002
 neighbor 169.254.21.2 remote-as 65001
 neighbor 169.254.21.2 update-source Tunnel101
 neighbor 169.254.22.6 remote-as 65001
 neighbor 169.254.22.6 update-source Tunnel102
```

## Critical Configuration Points

### 1. Tunnel Destinations
- **c8k-10 Tunnel101** → **gw-1-pip** (Azure Instance 0 public IP)
- **c8k-10 Tunnel102** → **gw-2-pip** (Azure Instance 1 public IP)
- **c8k-20 Tunnel101** → **gw-1-pip** (Azure Instance 0 public IP)
- **c8k-20 Tunnel102** → **gw-2-pip** (Azure Instance 1 public IP)

**Critical:** Each NVA must connect to **both** Azure instances to create the bow-tie. This is what provides full redundancy.

### 2. BGP Peer Addresses
Each tunnel must use the correct APIPA BGP peer address that matches the Azure Gateway's custom BGP IP configuration.

### 3. Static Routes to BGP Peers
Cisco requires static routes pointing BGP peer addresses through the correct tunnel interface:

```ios
! c8k-10 routes
ip route 169.254.21.2 255.255.255.255 Tunnel101
ip route 169.254.22.6 255.255.255.255 Tunnel102

! c8k-20 routes
ip route 169.254.21.2 255.255.255.255 Tunnel101
ip route 169.254.22.6 255.255.255.255 Tunnel102
```

**Note:** Both NVAs use the same BGP peer addresses because they both connect to the same Azure instances.

### 4. No Local Network Address Space
Unlike traditional LNG configurations, when using custom BGP APIPA addresses:
- Do **NOT** configure `localNetworkAddressSpace` in the LNG
- BGP handles route advertisement dynamically
- Each LNG specifies only a single `bgpPeeringAddress` (not an array)

## Deployment

Deploy the infrastructure using Azure CLI:

```bash
az deployment sub create \
  --location swedencentral \
  --template-file templates/main.bicep
```

## Verification

### Check Connection Status

```bash
az network vpn-connection show \
  --name con-1 \
  --resource-group vpn-bgp-apipa-lab-rg3 \
  --query connectionStatus
```

Expected: `Connected` for con-11, con-12, con-21, and con-22

### Check BGP Peers

```bash
az network vnet-gateway list-bgp-peer-status \
  --name client-Vnet-gw \
  --resource-group vpn-bgp-apipa-lab-rg3
```

Expected output showing 4 BGP peers in `Connected` state:
- 169.254.21.1
- 169.254.22.1
- 169.254.21.5
- 169.254.22.5

### Check Learned Routes

```bash
az network vnet-gateway list-learned-routes \
  --name client-Vnet-gw \
  --resource-group vpn-bgp-apipa-lab-rg3
```

Expected: Routes to 10.10.0.0/16 (provider VNet) learned via all 4 BGP peers

### Cisco Verification Commands

```ios
! Check tunnel status
show crypto ikev2 sa
show crypto ipsec sa

! Check BGP neighbors
show ip bgp summary

! Check BGP routes
show ip bgp
show ip route bgp
```

## Topology Summary

This configuration creates a **full mesh (bow-tie) topology**:

- **4 IPsec tunnels** established
- **4 BGP sessions** active
- **4 Azure Connections** (one per tunnel)
- **4 Local Network Gateways** (one per tunnel, even though only 2 unique public IPs)

The key insight: A true **bow-tie topology** requires each on-premises device to connect to **all** Azure Gateway instances. With 2 NVAs and 2 Azure instances, this creates 4 tunnels. Each tunnel needs its own LNG, even when multiple LNGs share the same public IP.

## Benefits of This Architecture

1. **Redundancy**: Multiple paths between Azure and on-premises
2. **Load Distribution**: Traffic can flow over all 4 tunnels
3. **Fast Convergence**: BGP detects and reroutes around failures quickly
4. **No Address Conflicts**: APIPA addresses avoid overlapping with existing networks
5. **Simplified Management**: Only 2 LNGs to manage instead of 4

## References

- [Azure VPN Gateway BGP Overview](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-bgp-overview)
- [Configure BGP for VPN Gateway](https://learn.microsoft.com/en-us/azure/vpn-gateway/bgp-howto)
- [AWS to Azure BGP VPN Connection](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-aws-bgp)
- [VPN Gateway Active-Active](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-activeactive-rm-powershell)

## Troubleshooting

### Error: "Multiple connections to LNGs with same IP not allowed"

**Cause:** This error can occur during deployment if the connection custom BGP IP configuration is incorrect or missing.

**Solution:** Ensure each connection has the correct `gatewayCustomBgpIpAddresses` configured:
- Connections to Instance 0 (con-11, con-21) should use primary IP: 169.254.21.2
- Connections to Instance 1 (con-12, con-22) should use secondary IP: 169.254.22.6
- The "not used" IP for each connection must still be valid

### BGP Sessions Not Establishing

**Common causes:**
1. Tunnel destinations incorrect (each NVA should connect to **both** gw-1-pip and gw-2-pip, not just one)
2. Missing static routes to BGP peer addresses on Cisco
3. APIPA addresses mismatched between Azure and Cisco configurations
4. IPsec tunnels not up (verify with `show crypto ipsec sa`)

### Tunnels Up But No Routes Learned

**Check:**
1. BGP ASN configuration matches on both sides
2. BGP `update-source` configured correctly on Cisco
3. Network statements configured in BGP to advertise routes
4. No BGP route filters blocking advertisements