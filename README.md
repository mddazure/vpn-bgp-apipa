# **Highly available Site-to-Site VPN with BGP over APIPA addresses**

This article describes the deployment of a [dual-redundant S2S VPN connection](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-highlyavailable#dual-redundancy-active-active-vpn-gateways-for-both-azure-and-on-premises-networks) between an Azure VNET Gateway in Active-Active mode, and a pair of Cisco 8000v Network Virtual Appliances in a VNET simulating an on-premise location. The VPN connection is dynamically routed through BGP as described in 
[About BGP and VPN Gateway](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-bgp-overview), with the BGP sessions using IP addresses from the APIPA (Automatic Private IP Addressing) range.

APIPA is a mechanism used by Windows, macOS, Linux, and network devices to automatically assign an IP address when no DHCP server is available. The APIPA address range is 169.254.0.0/16, as defined in RFC 3927 “Dynamic Configuration of IPv4 Link-Local Addresses”. APIPA addresses are *local* to their Layer 2 segment ((V)LAN or point-to-point link) and are *not routable* across subnets.

APIPA addresses are commonly used for in VPNs for these reasons:
- Avoids the need for "real" IP space for internal plumbing of the network
- BGP peer IPs only need to be reachable over the tunnel—not globally routable
- Using the APIPA range ensures BGP neighbor addresses never conflict with real networks

Azure VNET Gateway supports the use of APIPA addresses for BGP over S2S VPN. Gateways use their instance-level IP addresses (from the GatewaySubnet) for BGP by default, but can be configured to use APIPA addresses from the 169.254.21.0 to 169.254.22.255 range.

:point_right: Azure VNET Gateway does not support the entire APIPA range of 169.254.0.0/16, Custom BGP addresses must be taken from the 169.254.21.0 to 169.254.22.255 range.

VPN connections between Azure and Amazon Web Services (AWS) *must* use APIPA addresses for BGP - this is a requirement from AWS, as described in [How to connect AWS and Azure using a BGP-enabled VPN gateway](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-howto-aws-bgp).

## Architecture

The deployment consists of a Client-VNET, holding a VNET Gateway, and a Provider-VNET containing a pair of Cisco 8000v NVAs.

![image](/images/vpn-bgp-apipa.png)

Provider-VNET also contains Azure Route Server (ARS), which runs BGP with the NVAs. ARS inserts the routes dynamically learned by the NVAs over the VPN, into Provider-VNET's routing. This avoids the need for a UDR on the vm subnet to direct traffic to the NVAs. Client-VNET does not require ARS for this purpose as the VNET Gateway automatically inserts the routes it learns into Client-VNET's routing.

The NVA's each have *one* Public IP address, from which they source tunnels to *both* instance of the VNET Gateway.

:point_right: This is different from the AWS VPN connectition architecture referenced above, where each AWS Gateway instance has *two* public IP addresses, and the deployment described here *cannot* be used to connect to AWS. 

Two Local Network Gateway objects (LNGs) are deployed, each representing one NVA instance. Then two Connection objects connect the VNET Gateway to the LNGs. In Active-Active mode, Azure VNET Gateway establishes a tunnel from each of its instances to the remote device represented by an LNG. With two remote devices, each represented by one LNG, this results in a full bow-tie of tunnels as shown in the diagram above.

Each instance of the VNET Gateway is configured with two Custom (APIPA) BGP addresses. Each NVA has a Loopback interface which is assigned an APIPA address. BGP neighbors are established from each NVA, sourced from it Loopback interface to one Custom (APIPA) BGP address on each Gateway instance.

## Deploy
Log in to Azure Cloud Shell at https://shell.azure.com/ and select Bash.

Ensure Azure CLI and extensions are up to date:
  
      az upgrade --yes
  
If necessary select your target subscription:
  
      az account set --subscription <Name or ID of subscription>
  
Clone the  GitHub repository:
  
      git clone https://github.com/mddazure/vpn-bgp-apipa
  
Change directory:
  
      cd ./vpn-bgp-apipa

Accept the terms for the CSR8000v Marketplace offer:

      az vm image terms accept -p cisco -f cisco-c8000v-byol --plan 17_13_01a-byol -o none

Deploy the Bicep template:

      az deployment sub create --location swedencentral --template-file templates/main.bicep

Verify that all components in the diagram above have been deployed to the resourcegroup `vpn-bgp-apipa-lab-rg` and are healthy. 

Credentials to the Cisco 8000v NVAs and the other VMs:

Username = `AzureAdmin`

Password = `vpn@123456`

## Configure
Both Cisco 8000v NVA's are up but must still be configured.

Log in to the each NVA, preferably via the Serial console in the portal as this does not rely on network connectivity in the VNET. 
  - Serial console is under Support + troubleshooting in the Virtual Machine blade.

Enter credentials.

Enter Enable mode by typing `en` at the prompt, then enter Configuration mode by typing `conf t`. Paste in the below commands:

      license boot level network-advantage addon dna-advantage
      do wr mem
      do reload

The NVA will now reboot. When rebooting is complete log on again through Serial Console. Enter Enable mode by typing `en` at the prompt, then enter Configuration mode by typing `conf t`.

Retrieve the instance public IP addresses of VNET Gateway `client-Vnet-gw`  either from the output of the deployment or from the portal.

Copy [c8k-10.ios](https://raw.githubusercontent.com/mddazure/vpn-bgp-apipa/refs/heads/main/templates/c8k-10.ios) and [c8k-20.ios](https://raw.githubusercontent.com/mddazure/vpn-bgp-apipa/refs/heads/main/templates/c8k-10.ios) into Notepad and replace the [gw-1-pip] and [gw-2-pip] placeholders by  the gateway's public IP addresses.

Copy and paste the configurations into each of the NVAs. 

On both Cisco 8000v NVA's:

- Verify that the Tunnel interfaces are up by entering `sh ip int brief`:

```
c8k-10#sh ip int brief
Interface              IP-Address      OK? Method Status                Protocol
GigabitEthernet1       10.10.0.4       YES DHCP   up                    up      
GigabitEthernet2       10.10.1.4       YES DHCP   up                    up      
Loopback0              169.254.21.1    YES manual up                    up      
Tunnel101              10.100.10.1     YES manual up                    up 
Tunnel102              10.100.10.2     YES manual up                    up      
VirtualPortGroup0      192.168.35.101  YES NVRAM  up                    up
```

- Verify that the BGP neighbors relationships to the VNET Gateway and to Azure Route Server are established by entering `sh ip bgp summary`:

```
c8k-10#sh ip bgp summary
BGP router identifier 169.254.21.1, local AS number 65002
BGP table version is 5, main routing table version 5
4 network entries using 992 bytes of memory
8 path entries using 1088 bytes of memory
2/2 BGP path/bestpath attribute entries using 592 bytes of memory
2 BGP AS-PATH entries using 48 bytes of memory
0 BGP route-map cache entries using 0 bytes of memory
0 BGP filter-list cache entries using 0 bytes of memory
BGP using 2720 total bytes of memory
BGP activity 55/51 prefixes, 396/388 paths, scan interval 60 secs
5 networks peaked at 16:11:21 Jan 24 2026 UTC (1d17h ago)

Neighbor        V           AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
10.10.4.4       4        65515       4       6        5    0    0 00:01:07        1
10.10.4.5       4        65515       4       6        5    0    0 00:01:08        1
169.254.21.2    4        65001       5       6        5    0    0 00:01:03        3
169.254.21.6    4        65001       5       6        5    0    0 00:01:03        3
```
In this output, the field under State should be empty, and PfxRcd (the number of prefixes receivd from this neighbor) should show a number. If a neighbor a relationship is not established, the output will be similar to this:

```
Neighbor        V           AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
...
169.254.21.2    4        65001       0       0        1    0    0 00:00:25 Idle
...
```
## Inspect
Now let's look at what the configuration looks like on the Azure end of the connection.

In the portal, navigate to `client-Vnet-gw` under the `vpn-bgp-apipa-lab-rg` Resource group.
The overview page shows graphs for Total tunnel ingress and Total tunnel egress traffic:
![image](/images/client-vnet-gw-overview.png)

The Configuration page shows the Custom APIPA BGP addresses that have been configured during the deployment:
![image](/images/client-vnet-gw-configuration.png)

These are optional. If left blank, the Gateway will default to the private ip addresses of the instances, taken from the GatewaySubnet, to source its BGP neighbor relationships. These cannot be changed.

Now navigate to Local Network Gateway (LNG) `lng-c8k-10`. LNG's represent the "remote end" of the VPN connection, from the perspective of the VPN Gateway.

The Configuration page contains the details of Cisco 8000v NVA: its public ip address and BGP details.
![image](/images/lng-c8k-10-config.png)

The Connection element ties the VNET Gateway and the LNG together.
Navigate to Connection `con-c8k-10`. 

The Overview page shows that this Connection links `client-Vnet-gw` with `lng-c8k-10`. As the VNET Gateway is configured for Active-active mode, this single Connection element actually represents two IPSec tunnels: one to each instance of the VNET Gateway.
![image](/images/con-c8k-10-overview.png)


The Authentication page contains the Shared Key for the VPN connection. This must be identical to the key configured on the NVAs in the `crypto ikev2 keyring ...` section of the ios configuration.

The Configuration page shows the details of the Connection. Note that we are using Custom IKE and IPSec policies. These policies must be mirrored exactly on the NVA's, and Azure's Default settings include parameters that are no longer supported in Cisco IOS. The Custom settings used here are supported on the Cisco devices.

![image](/images/con-c8k-10-config.png)

Custom BGP Addresses contains the APIPA BGP addresses of both instances of the VNET Gateway. Connection `con-c8k-10` holds the first APIPA address of each instance, `con-c8k-20` the second address. This matches the configuration on the NVAs - `c8k-10` has neighbor relationship from it loopback0 interface to the first gateway instance APIPA addresses, `c8k-20` to the second.

| NVA    |Tunnel    | NVA BGP IP   | Gateway   |Gateway BGP IP|
|--------|----------|--------------|-----------|--------------|
| c8k-10 |Tunnel101 | 169.254.21.1 | Instance0 |169.254.21.2  |
| c8k-10 |Tunnel102 | 169.254.21.1 | Instance1 |169.254.21.6  |
| c8k-20 |Tunnel101 | 169.254.22.1 | Instance0 |169.254.22.2  |
| c8k-20 |Tunnel102 | 169.254.22.1 | Instance1 |169.254.22.6  |

## Test
Log on to `client-Vm` via Serial Console in the portal.

Call the web servers `provider-Web1` and `provider-Web2` at `10.10.2.5` and 10.10.2.6` via Curl. Both should respond with their names:

```
AzureAdmin@client-Vm:~$ curl 10.10.2.5
provider-Web1
AzureAdmin@client-Vm:~$ curl 10.10.2.6
provider-Web2
```
Download and run a shell script to continuously call both web servers:
```
wget https://raw.githubusercontent.com/mddazure/vpn-bgp-apipa/refs/heads/main/templates/loop.sh && sudo chmod +x loop.sh && ./loop.sh

```

```
AzureAdmin@client-Vm:~$ wget https://raw.githubusercontent.com/mddazure/vpn-bgp-apipa/refs/heads/main/templates/loop.sh && sudo chmod +x loop.sh && ./loop.sh
--2026-01-26 13:17:31--  https://raw.githubusercontent.com/mddazure/vpn-bgp-apipa/refs/heads/main/templates/loop.sh
Resolving raw.githubusercontent.com (raw.githubusercontent.com)... 185.199.108.133, 185.199.109.133, 185.199.110.133, ...
Connecting to raw.githubusercontent.com (raw.githubusercontent.com)|185.199.108.133|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 91 [text/plain]
Saving to: ‘loop.sh.1’

loop.sh.1           100%[===================>]      91  --.-KB/s    in 0s      

2026-01-26 13:17:31 (6.38 MB/s) - ‘loop.sh.1’ saved [91/91]

provider-Web1
provider-Web2
provider-Web1
provider-Web2
provider-Web1
provider-Web2
provider-Web1
provider-Web2
provider-Web1
```

Now simulate a failure of NVA c8k-10:
- log on to the device via Serial Console
- shut down the device's outside interface

```
c8k-10>en
c8k-10#conf t
Enter configuration commands, one per line.  End with CNTL/Z.
c8k-10(config)#int gig1
c8k-10(config-if)#shut
c8k-10(config-if)#
*Jan 26 13:39:48.409: %LINEPROTO-5-UPDOWN: Line protocol on Interface Tunnel102, changed state to down
*Jan 26 13:39:48.411: %LINEPROTO-5-UPDOWN: Line protocol on Interface Tunnel101, changed state to down
*Jan 26 13:39:48.461: %CRYPTO-6-ISAKMP_ON_OFF: ISAKMP is OFFend
*Jan 26 13:39:50.417: %LINK-5-CHANGED: Interface GigabitEthernet1, changed state to administratively down
*Jan 26 13:39:51.417: %LINEPROTO-5-UPDOWN: Line protocol on Interface GigabitEthernet1, changed state to down
c8k-10#
```

This will bring down the tunnels from c8k-10 to both instances of the VNET Gateway. Depending on via which NVA traffic was being routed, this may interrupt the flow between client-Vm and the web servers. 

BGP will eventually detect the outage and reconverge via the alternate path, when its holddown timer expires. This is the time a BGP router will wait for a keepalive message from its peer,  before considering the connection down and reconverging to an alternative path. The default is set to 180 seconds, and connectivity may be interrupted for this time.

In some BGP applications, such as Expresroute, Bidirectional Forward Detection (BFD) is used to detect link failures and reconverge within seconds. BFD is not supported for Site-to-Site (S2S) VPN connections with BGP. This is because S2S VPNs traverse the public internet, where packet delay or occasional loss is normal. Using aggressive BFD timers in such environments can cause instability, leading to route flapping.













