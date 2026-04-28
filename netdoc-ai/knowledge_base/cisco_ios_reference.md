# Cisco IOS / IOS-XE / NX-OS Reference Guide

## Platform Identification (show version)

| String in output          | Platform family       |
|---------------------------|-----------------------|
| Cisco IOS XE              | ISR4K, ASR1K, CSR1KV  |
| Cisco IOS                 | ISR, 7200, 6500 (CatOS)|
| NX-OS                     | Nexus 5K/7K/9K        |
| Cisco IOS XR              | ASR9K, CRS, NCS       |
| Adaptive Security Appliance | ASA firewall        |

## Interface Naming Conventions

| Short form | Full name              | Common use         |
|------------|------------------------|--------------------|
| Gi0/0/0    | GigabitEthernet0/0/0   | Uplink / LAN       |
| Te1/0/1    | TenGigabitEthernet     | High-speed uplink  |
| Fa0/0      | FastEthernet           | Legacy access      |
| Lo0        | Loopback0              | Router-ID, mgmt    |
| Tu0        | Tunnel0                | GRE / IPsec VPN    |
| Po1        | Port-channel1          | LAG / LACP bond    |
| Vl10       | Vlan10 (SVI)           | Layer-3 gateway    |
| Se0/0/0    | Serial0/0/0            | WAN / MPLS         |
| BVI1       | Bridge-Group Virtual   | Wireless bridging  |

## Status Codes (show ip interface brief)

| Status        | Protocol | Meaning                          |
|---------------|----------|----------------------------------|
| up            | up       | Fully operational                |
| up            | down     | L1 OK, L2/3 issue (keepalive?)  |
| down          | down     | Cable / far-end down             |
| administratively down | down | Shutdown by config          |

## BGP State Machine

| State        | Meaning                                         |
|--------------|-------------------------------------------------|
| Idle         | BGP waiting or refused                          |
| Connect      | TCP connection being established                |
| Active        | Retrying TCP — peer unreachable                 |
| OpenSent     | OPEN message sent                               |
| OpenConfirm  | Waiting for KEEPALIVE                           |
| Established  | Session up, exchanging prefixes                 |

## OSPF Neighbor States

Idle → Attempt → Init → 2-Way → ExStart → Exchange → Loading → **Full**

- **2-Way**: DR/BDR election complete; non-DR routers stop here
- **Full**: Databases synchronised; healthy state

## HSRP / VRRP Quick Reference

- HSRP group priority default: 100 (higher wins)
- Active router = highest priority (tie-break: highest IP)
- Virtual IP is the default gateway for hosts
- `standby X preempt` allows reclaiming active role after recovery

## Common Risk Indicators

| Observation                        | Risk    | Note                              |
|------------------------------------|---------|-----------------------------------|
| `service telnet` or VTY with telnet | HIGH   | Cleartext credential exposure     |
| No `service password-encryption`   | HIGH    | Type-0/7 passwords in clear       |
| `no ip ssh version 2`              | MEDIUM  | SSHv1 is deprecated               |
| VTY with `no access-class`         | MEDIUM  | Unrestricted management access    |
| `no cdp run` missing (CDP enabled) | LOW     | Topology information disclosure   |
| `no ip proxy-arp` missing          | LOW     | Potential ARP proxy issues        |
| NTP not synchronised               | MEDIUM  | Log timestamps unreliable         |
| No `logging` server configured     | MEDIUM  | No SIEM visibility                |
| Default SNMP community `public`    | HIGH    | Community [REDACTED] per policy   |
| ip http server enabled             | HIGH    | Unencrypted HTTP management       |
| No `ip ssh source-interface`       | LOW     | SSH may egress wrong interface    |

## ACL Interpretation

- Named vs numbered ACLs: numbered legacy (1–99 standard, 100–199 extended)
- `permit ip any any` at end = effectively no filtering (flag as risk)
- `deny ip any any log` at end = correct deny-all with logging
- Implicit deny: all IOS ACLs end with implicit `deny any`
- Wildcard mask: inverse of subnet mask (0.0.0.255 = /24)

## BGP Community Reference (common RFC values)

| Community      | Meaning                        |
|----------------|--------------------------------|
| 0:0            | Internet (no_export override)  |
| 65535:0        | graceful-shutdown (RFC 8326)   |
| 65535:65281    | no-export                      |
| 65535:65282    | no-advertise                   |
| 65535:65283    | local-AS                       |

## NTP Security Notes

- Prefer `ntp authenticate` with MD5 keys
- Stratum 1 = directly connected to reference clock
- Stratum 16 = unsynchronised
- `Clock is synchronized, stratum X` = healthy
