# VPN Gateway with BGP and APIPA Addresses

This repository demonstrates how to configure an Azure Active-Active VPN Gateway with BGP using APIPA (Automatic Private IP Addressing) custom addresses to establish a full mesh (bow-tie) connectivity with two Cisco 8000v Network Virtual Appliances (NVAs).

## Architecture Overview

```
Cisco c8k-10 (Single Public IP)          Azure VPN Gateway (Active-Active)
┌─────────────────────────────┐         ┌──────────────────────────────────┐
│ Public IP: 4.225.32.208     │         │ Instance 0 (gw-1-pip)            │
│                             │─────────│  • Public IP: x.x.x.x            │
│ Tunnel101: 169.254.21.1  ───┼────┐    │  • BGP IP: 169.254.21.2          │
│ Tunnel102: 169.254.22.1  ───┼──┐ │    │  • BGP IP: 169.254.22.2          │
└─────────────────────────────┘  │ │    │                                  │
                                 │ │    │ Instance 1 (gw-2-pip)            │
Cisco c8k-20 (Single Public IP)  │ │    │  • Public IP: y.y.y.y            │
┌─────────────────────────────┐  │ │    │  • BGP IP: 169.254.21.6          │
│ Public IP: 4.225.33.15      │  │ │    │  • BGP IP: 169.254.22.6          │
│                             │──┼─┼────│                                  │
│ Tunnel101: 169.254.21.5  ───┼──┘ │    │                                  │
│ Tunnel102: 169.254.22.5  ───┼────┘    │                                  │
└─────────────────────────────┘         └──────────────────────────────────┘

Azure Resources:
├─ 2 Local Network Gateways (lng-1, lng-2)
├─ 2 Connections (con-1, con-2)
└─ 4 IPsec Tunnels (full bow-tie topology)
```

![Architecture Diagram](/images/vpn-bgp-apipa.png)

## Key Design Principles

### 1. Two LNGs for Four Tunnels

**Critical Difference from AWS Setup:**

The [Microsoft AWS-Azure BGP documentation](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-aws-bgp) describes a setup with **4 Local Network Gateways** because:
- AWS site-to-site VPN connections provide **2 outside IP addresses per connection**
- Each tunnel has its own distinct public IP

In this Cisco NVA setup:
- **Each Cisco NVA has only 1 public IP address**
- Multiple tunnels from the same NVA share the same outside IP
- Therefore, we only need **2 LNGs** (one per NVA)

**How 2 LNGs Create 4 Tunnels:**

Each LNG in this configuration:
- Points to a single public IP (the NVA's outside interface)
- Defines **two APIPA BGP peer addresses** (one for each tunnel)
- Creates **one Connection** resource

Each Connection resource:
- Specifies **two custom BGP IP addresses** (one per Azure VPN Gateway instance)
- Automatically establishes **two IPsec tunnels** (one to each active-active gateway instance)

**Result: 2 LNGs × 2 tunnels per connection = 4 total tunnels**

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

The configuration establishes **4 BGP sessions**:

1. **c8k-10 Tunnel101** (169.254.21.1) ↔ **Azure Instance 0** (169.254.21.2)
2. **c8k-10 Tunnel102** (169.254.22.1) ↔ **Azure Instance 0** (169.254.22.2)
3. **c8k-20 Tunnel101** (169.254.21.5) ↔ **Azure Instance 1** (169.254.21.6)
4. **c8k-20 Tunnel102** (169.254.22.5) ↔ **Azure Instance 1** (169.254.22.6)

**Important BGP Details:**
- Azure VPN Gateway ASN: **65001**
- Cisco NVAs ASN: **65002**
- Each Azure VPN Gateway instance has **two custom BGP IPs** configured
- Each Cisco NVA establishes **two BGP sessions** to the same Azure Gateway instance

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

Each LNG defines two BGP peer addresses:

**lng-1 (for c8k-10):**
```bicep
properties: {
  gatewayIpAddress: '<c8k-10-public-ip>'
  bgpSettings: {
    asn: 65002
    bgpPeeringAddresses: [
      { customBgpIpAddress: '169.254.21.1' }
      { customBgpIpAddress: '169.254.22.1' }
    ]
  }
}
```

**lng-2 (for c8k-20):**
```bicep
properties: {
  gatewayIpAddress: '<c8k-20-public-ip>'
  bgpSettings: {
    asn: 65002
    bgpPeeringAddresses: [
      { customBgpIpAddress: '169.254.21.5' }
      { customBgpIpAddress: '169.254.22.5' }
    ]
  }
}
```

### Connection Configuration

Each connection specifies which Azure Gateway custom BGP IPs to use:

**con-1 (to c8k-10):**
```bicep
gatewayCustomBgpIpAddresses: [
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig'
    customBgpIpAddress: '169.254.21.2'
  }
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig2'
    customBgpIpAddress: '169.254.22.2'
  }
]
```

**con-2 (to c8k-20):**
```bicep
gatewayCustomBgpIpAddresses: [
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig'
    customBgpIpAddress: '169.254.21.6'
  }
  {
    ipConfigurationId: '<gateway-id>/ipConfigurations/vnetgwconfig2'
    customBgpIpAddress: '169.254.22.6'
  }
]
```

## Cisco 8000v Configuration

### c8k-10 Configuration

Both tunnels terminate at the **same Azure Gateway instance** (gw-1-pip):

```ios
interface Tunnel101
 description tunnel 1 to gw-1 (169.254.21.0/30)
 ip address 169.254.21.1 255.255.255.255
 tunnel source GigabitEthernet1
 tunnel destination [gw-1-pip]
 tunnel protection ipsec profile IPSEC-PROFILE

interface Tunnel102
 description tunnel 2 to gw-1 (169.254.22.0/30)
 ip address 169.254.22.1 255.255.255.255
 tunnel source GigabitEthernet1
 tunnel destination [gw-1-pip]
 tunnel protection ipsec profile IPSEC-PROFILE

router bgp 65002
 neighbor 169.254.21.2 remote-as 65001
 neighbor 169.254.21.2 update-source Tunnel101
 neighbor 169.254.22.2 remote-as 65001
 neighbor 169.254.22.2 update-source Tunnel102
```

### c8k-20 Configuration

Both tunnels terminate at the **same Azure Gateway instance** (gw-2-pip):

```ios
interface Tunnel101
 description tunnel 1 to gw-2 (169.254.21.4/30)
 ip address 169.254.21.5 255.255.255.255
 tunnel source GigabitEthernet1
 tunnel destination [gw-2-pip]
 tunnel protection ipsec profile IPSEC-PROFILE

interface Tunnel102
 description tunnel 2 to gw-2 (169.254.22.4/30)
 ip address 169.254.22.5 255.255.255.255
 tunnel source GigabitEthernet1
 tunnel destination [gw-2-pip]
 tunnel protection ipsec profile IPSEC-PROFILE

router bgp 65002
 neighbor 169.254.21.6 remote-as 65001
 neighbor 169.254.21.6 update-source Tunnel101
 neighbor 169.254.22.6 remote-as 65001
 neighbor 169.254.22.6 update-source Tunnel102
```

## Critical Configuration Points

### 1. Tunnel Destinations
- **c8k-10**: Both Tunnel101 and Tunnel102 → **gw-1-pip** (Azure Instance 0 public IP)
- **c8k-20**: Both Tunnel101 and Tunnel102 → **gw-2-pip** (Azure Instance 1 public IP)

**Common Mistake:** Configuring Tunnel102 to point to the "other" Azure instance. Each NVA should establish both tunnels to the **same** Azure VPN Gateway instance.

### 2. BGP Peer Addresses
Each tunnel must use the correct APIPA BGP peer address that matches the Azure Gateway's custom BGP IP configuration.

### 3. Static Routes to BGP Peers
Cisco requires static routes pointing BGP peer addresses through the correct tunnel interface:

```ios
! c8k-10 routes
ip route 169.254.21.2 255.255.255.255 Tunnel101
ip route 169.254.22.2 255.255.255.255 Tunnel102

! c8k-20 routes
ip route 169.254.21.6 255.255.255.255 Tunnel101
ip route 169.254.22.6 255.255.255.255 Tunnel102
```

### 4. No Local Network Address Space
Unlike traditional LNG configurations, when using custom BGP APIPA addresses:
- Do **NOT** configure `localNetworkAddressSpace` in the LNG
- BGP handles route advertisement dynamically
- APIPA addresses are specified in `bgpPeeringAddresses` array

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

Expected: `Connected` for both con-1 and con-2

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
- **2 Azure Connections** managing all tunnels
- **2 Local Network Gateways** (not 4, despite having 4 tunnels)

The key insight: When your on-premises devices have **a single public IP per device**, you need **one LNG per device**, regardless of how many tunnels each device creates. The LNG's `bgpPeeringAddresses` array allows you to define multiple APIPA addresses for different tunnels from the same public IP.

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

**Solution:** Ensure each connection has unique `gatewayCustomBgpIpAddresses` configured:
- con-1 should use 169.254.21.2 and 169.254.22.2
- con-2 should use 169.254.21.6 and 169.254.22.6

### BGP Sessions Not Establishing

**Common causes:**
1. Tunnel destinations incorrect (both tunnels from one NVA should point to the same Azure instance)
2. Missing static routes to BGP peer addresses on Cisco
3. APIPA addresses mismatched between Azure and Cisco configurations
4. IPsec tunnels not up (verify with `show crypto ipsec sa`)

### Tunnels Up But No Routes Learned

**Check:**
1. BGP ASN configuration matches on both sides
2. BGP `update-source` configured correctly on Cisco
3. Network statements configured in BGP to advertise routes
4. No BGP route filters blocking advertisements