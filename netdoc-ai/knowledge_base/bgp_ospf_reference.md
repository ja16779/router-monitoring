# BGP & OSPF Interpretation Reference

## BGP Summary Output Parsing (show ip bgp summary)

```
Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
192.168.1.1     4 65001    1234    1100      456    0    0 01:23:45        512
10.0.0.2        4 65002       0       5        0    0    0 00:00:31    Active
```

| Field       | Meaning                                           |
|-------------|---------------------------------------------------|
| Neighbor    | Peer IP address                                   |
| V           | BGP version (always 4)                            |
| AS          | Peer's autonomous system number                   |
| MsgRcvd/Sent| BGP messages exchanged (health indicator)         |
| TblVer      | Current BGP table version                         |
| InQ/OutQ    | Update queue depth (should be 0; if >0 → congestion)|
| Up/Down     | Session uptime or time since last reset           |
| State/PfxRcd| "Established" shows prefix count; otherwise = state|

**Key interpretations:**
- `Active` state = peer is unreachable (TCP not established)
- `Idle (Admin)` = peer shut down administratively
- Prefix count = 0 on Established = peer up but sending no routes
- Very high MsgRcvd with low Up/Down = session flapping

## OSPF Neighbor Parsing (show ip ospf neighbor)

```
Neighbor ID   Pri   State      Dead Time  Address        Interface
1.1.1.1        1   FULL/DR    00:00:38   10.0.0.2       GigabitEthernet0/0
2.2.2.2        1   FULL/BDR   00:00:39   10.0.0.3       GigabitEthernet0/0
```

- FULL/DR = this router's neighbor is the Designated Router
- FULL/BDR = Backup Designated Router neighbor
- FULL/  (hyphen) = P2P link, no DR election
- Dead Time < 10s consistently = potential instability

## Route Table Interpretation (show ip route)

Route codes:
```
C - Connected, S - Static, R - RIP, M - Mobile, B - BGP
D - EIGRP, EX - EIGRP external, O - OSPF, IA - OSPF inter area
N1/N2 - OSPF NSSA, E1/E2 - OSPF external, i - IS-IS
* - candidate default, U - per-user static, o - ODR
```

**Default route indicators:**
- `S* 0.0.0.0/0` = static default route
- `B* 0.0.0.0/0` = BGP-learned default (check from whom)
- `O*E2 0.0.0.0/0` = OSPF redistributed default

**AD (Administrative Distance) reference:**
| Protocol       | Default AD |
|----------------|-----------|
| Connected      | 0         |
| Static         | 1         |
| EIGRP summary  | 5         |
| eBGP           | 20        |
| OSPF           | 110       |
| IS-IS          | 115       |
| EIGRP internal | 90        |
| EIGRP external | 170       |
| iBGP           | 200       |

## VRF Documentation (show vrf / show ip vrf)

```
  Name                             Default RD            Protocols   Interfaces
  MGMT                             1:100                 ipv4        Lo100 Gi0/0/0.100
  CUSTOMER_A                       65001:100             ipv4        Gi0/1 Gi0/2
```

- Route Distinguisher (RD): makes prefixes unique across VRFs in MP-BGP
- Route Target (RT): controls import/export between VRFs
- Document each VRF purpose, RD, RT values, and attached interfaces

## BGP Route Reflector Identification

Presence of `bgp cluster-id` or `neighbor X route-reflector-client` = Route Reflector.
Document: cluster-id, list of RR clients, upstream RR peers.

## MPLS / Label Forwarding

- `show mpls forwarding-table` and `show mpls ldp neighbor` presence = MPLS enabled
- LDP neighbor state `Oper` = operational label distribution
- Note any LDP session protection or LDP-IGP synchronization config
