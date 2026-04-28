# Network Design Document Template

Use this exact structure for every document you produce:

---

# Network Design Document
**Device:** {HOSTNAME}
**Date:** {DATE}
**Prepared by:** NetDocAI (AI-Assisted Documentation)
**Classification:** INTERNAL USE ONLY

---

## 1. Executive Summary
Brief 3–5 sentence summary of the device's role, platform, and key findings.

---

## 2. Device Identity
| Field            | Value |
|------------------|-------|
| Hostname         |       |
| Platform / Model |       |
| IOS / NX-OS Version |   |
| Serial Number    |       |
| Uptime           |       |
| Config Register  |       |
| Last Reload Reason |    |

---

## 3. Interface Inventory
List all physical and logical interfaces with status, IP, and description.

| Interface | IP Address / Mask | Status | Protocol | Description |
|-----------|-------------------|--------|----------|-------------|

---

## 4. VLAN & Layer-2 Topology
- VLAN table (ID, Name, Active ports)
- Trunk ports and allowed VLANs
- Spanning Tree mode and root status
- EtherChannel / Port-Channel summary

---

## 5. Routing Protocol Summary

### 5a. Static Routes
| Prefix | Next-Hop | AD | Interface |
|--------|----------|----|-----------|

### 5b. OSPF
- Process ID, Router-ID, Areas, Neighbors

### 5c. BGP
- AS Number, Router-ID
- Neighbor table (peer IP, remote AS, state, prefixes received/sent)
- Route Reflector / Confederation details if present

### 5d. EIGRP (if present)
### 5e. Other protocols

---

## 6. VRF / Segmentation
| VRF Name | RD | Import RT | Export RT | Interfaces |
|----------|----|-----------|-----------|------------|

---

## 7. High Availability
- HSRP / VRRP groups (group, virtual IP, priority, state)
- Redundant uplinks / dual-homed links

---

## 8. Security Posture
- AAA configuration (TACACS+, RADIUS)
- SSH version, VTY access-class
- Control-plane policing (CoPP)
- ACLs (name, interface, direction, rule count — no actual secrets)
- NAT/PAT configuration
- Crypto / VPN sessions
- Weak or deprecated features observed (telnet enabled, no service password-encryption, etc.)

---

## 9. Operational Observations
- NTP sync status
- Logging destination(s)
- Environment (temperature, power supply status)
- CDP neighbors and topology clues

---

## 10. Risk Register
| # | Risk Description | Severity | Recommendation |
|---|-----------------|----------|----------------|

Severity levels: **HIGH** / **MEDIUM** / **LOW**

---

## 11. Suggested Follow-Up Validations
Numbered list of recommended follow-on commands or checks for the operations team.

---

## 12. Raw Data Appendix Note
All CLI outputs were sanitised before processing. Passwords, keys, and
community strings appear as [REDACTED] in accordance with data classification policy.
