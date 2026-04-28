# Network Security Posture Analysis Guide

## CIS Cisco IOS Benchmark Key Controls

### Management Plane Hardening
- SSH v2 only (`ip ssh version 2`)
- VTY lines: SSH transport only (`transport input ssh`)
- VTY access-class restricting to mgmt subnet
- Console line timeout (`exec-timeout 5 0`)
- Enable secret (not enable password) — type 5 or 9
- `service password-encryption` at minimum (type 7 — weak but better than clear)
- Disable unused services: `no ip http server`, `no ip http secure-server` if unused
- Disable CDP on external/untrusted interfaces
- Disable proxy-ARP: `no ip proxy-arp`
- Disable directed broadcasts: `no ip directed-broadcast`
- Disable IP source routing: `no ip source-route`

### Control Plane Policing (CoPP)
Presence of `policy-map CoPP` or `control-plane` section with rate-limiters is a
positive security indicator. Absence on edge routers is a HIGH risk.

### AAA Framework
- TACACS+ preferred over RADIUS for device management (command accounting)
- `aaa new-model` must be present
- `aaa authentication login default group tacacs+ local` (local as fallback)
- `aaa accounting commands 15 default start-stop group tacacs+`
- Local admin account should be minimal (break-glass only)

### IPsec / Crypto
- IKEv2 preferred over IKEv1 (IKEv1 deprecated per RFC 9395)
- Pre-shared keys → flag as MEDIUM (certificate auth preferred)
- `crypto isakmp key` / `set preshared-key` → REDACTED in output
- Check for weak encryption: DES/3DES → HIGH risk; prefer AES-256
- Check for weak hashing: MD5 → MEDIUM risk; prefer SHA-256/384

### Routing Security
- BGP: `neighbor X password` configured = authentication present (content REDACTED)
- BGP: prefix-list / route-map filtering on eBGP peers expected
- OSPF: `area X authentication message-digest` expected
- No route-map on eBGP neighbor = potential route leak risk (flag MEDIUM)
- `maximum-paths` and `bgp bestpath as-path multipath-relax` — document if present

### SNMP
- SNMPv3 with authPriv mode is the only acceptable version
- SNMPv1/v2c community strings → HIGH risk (even if REDACTED)
- `snmp-server community [REDACTED]` present = flag HIGH, recommend migration to v3

### Syslog
- `logging host X.X.X.X` present = centralized logging (positive)
- `logging buffered 16384` recommended
- `logging trap informational` minimum; `debugging` level may expose credentials
- No logging server = MEDIUM risk (no SIEM visibility)

### NTP
- `ntp server X.X.X.X prefer` — should point to internal Stratum 1/2
- `ntp authenticate` + `ntp authentication-key` = authentication enabled (positive)
- Without NTP: log timestamps unreliable → forensics impaired → MEDIUM risk

## Risk Scoring Framework

### HIGH Risk
Immediate remediation recommended. Potential for data breach, unauthorized access,
or service disruption.

### MEDIUM Risk
Remediation within next change window. Violates hardening baseline but requires
active exploitation or specific conditions.

### LOW Risk
Best-practice improvement. Address in next planned maintenance cycle.

## Common Misconfigurations to Flag

1. `ip classless` missing (rare on modern IOS but check)
2. `no ip default-network` when static default expected
3. BGP `neighbor X soft-reconfiguration inbound` without route-refresh capability
4. OSPF MTU mismatch (neighbors stuck in EXSTART/EXCHANGE)
5. Duplicate router-IDs (check across OSPF/BGP)
6. VRF route-leaking without explicit policy (accidental prefix import)
7. `ip nat inside` / `ip nat outside` without corresponding translation rules
8. ACL applied inbound on loopback (ineffective — loopback ignores inbound ACL)
9. `spanning-tree portfast` on trunk ports (BPDU guard bypass risk)
10. HSRP preempt missing on primary router (won't reclaim active role after recovery)
