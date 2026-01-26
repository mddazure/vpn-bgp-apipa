# **Highly available Site-to-Site VPN with BGP over APIPA addresses**

This article describes the deployment of a [dual-redundant S2S VPN connection](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-highlyavailable#dual-redundancy-active-active-vpn-gateways-for-both-azure-and-on-premises-networks) between an Azure VNET Gateway in Active-Active mode, and a pair of Cisco 8000v Network Virtual Appliances in a VNET simulating an on-premise location. The VPN connection is dynamically routed through BGP as described in 
[About BGP and VPN Gateway](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-bgp-overview), with the BGP sessions using IP addresses from the APIPA (Automatic Private IP Addressing) range.

APIPA is a mechanism used by Windows, macOS, Linux, and network devices to automatically assign an IP address when no DHCP server is available. The APIPA address range use is 169.254.0.0/16, as defined in RFC 3927 “Dynamic Configuration of IPv4 Link-Local Addresses”. APIPA addresses are *local* to their Layer 2 segment ((V)LAN or point-to-point link) and are *not routable* across subnets.

APIPA addresses are commonly used for in VPNs for following for these reasons:
- Avoids the need for "real" IP space for internal plumbing of the network
- BGP peer IPs only need to be reachable over the tunnel—not globally routable
- APIPA ensures the IPs never conflict with real networks

Azure VNET Gateway supports the use of APIPA addresses for BGP over S2S VPN. Gateways use their instance-level IP addresses (from the GatewaySubnet) for BGP by default, but can be configured to use APIPA addresses from the 169.254.21.0 to 169.254.22.255 range.

:point_right: Azure VNET Gateway does not support the entire APIPA range of 169.254.0.0/16, instance Custom BGP addresses must be taken from the 169.254.21.0 to 169.254.22.255 range.

VPN connections between Azure and Amazon Web Services (AWS) *must* use APIPA addresses for BGP - this is a requirement from AWS, as described in [How to connect AWS and Azure using a BGP-enabled VPN gateway](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-aws-bgp).

## Architecture

The deployment consists of a Client-VNET, holding a VNET Gateway, and a Provider-VNET containing a pair of Cisco 8000v NVAs.

![image](/images/vpn-bgp-apipa.png)

Provider-VNET also contains Azure Route Server (ARS), which runs BGP with the NVAs. ARS inserts the routes dynamically learned by the NVAs over the VPN, into Provider-VNET's routing. This avoids the need for a UDR on the vm subnet to direct traffic to the NVAs. Client-VNET does not require ARS for this purpose as the VNET Gateway automatically inserts the route it learns into Client-VNET's routing.

The NVA's each have *one* Public IP address, from which they source tunnels to *both* instance of the VNET Gateway.
:point_right: this is different from the AWS arhcitecture reference above, where each AWS Gateway instance has *two* public IP addresses, and the deployment described here *cannot* be used to connect to AWS.

Two Local Network Gateway objects (LNGs) are deployed, each representing one NVA instance. Then two Connection objects connect the VNET Gateway to the LNGs. In Active-Active mode, Azure VNET Gateway establishes a tunnel from each of its instances to the remote device represented by an LNG. With two remote devices, each represented by one LNG, this results in a full bow-tie of tunnels as shown in the diagram above.

Each instance of the VNET Gateway is configured with two Custom (APIPA) BGP addresses. Each NVA has a Loopback interface which assigned an APIPA address. BGP neighbors are established from each NVA, sourced from it Loopback interface to one Custom (APIPA) BGP address on each Gateway instance.

|


