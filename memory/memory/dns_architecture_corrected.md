---
name: DNS Architecture (Corrected)
description: Correct DNS chain with NextDNS and apk package manager
type: project
---

# DNS Architecture - CORRECTED 2026-04-18

## Complete Chain
```
Clients → dnsmasq:53 → AdGuardHome:3053 → Unbound:5335 → NextDNS (TLS)
```

## Component Details

### dnsmasq (port 53)
- Local DNS caching entry point
- Upstream: `127.0.0.1:3053` (AdGuard Home)
- Handles local `.lan` names

### AdGuard Home (port 3053)
- DNS filtering and blocking layer
- Upstream: `127.0.0.1:5335` (Unbound for recursion)
- Bootstrap DNS: NextDNS IPs (45.90.28.245, 45.90.30.245)

### Unbound (port 5335)
- Pure recursive DNS resolver
- **Fallback/Upstream: NextDNS** (NOT Google/Cloudflare)
  - IPv4: 45.90.28.245, 45.90.30.245
  - IPv6: 2a07:a8c0::, 2a07:a8c1::
- Auth zones: root.zone, arpa.zone, in-addr.arpa.zone
- DNSSEC enabled
- root.hints: `/etc/unbound/root.hints` (auto-updated daily)

### NextDNS
- Final upstream DNS with TLS encryption
- Profile: 29e346.dns.nextdns.io
- IOT filtering + security

## Package Manager
- **apk** (Alpine Package Kit) - NOT opkg
- Location: `/usr/bin/apk`
- Used for: `apk update`, `apk add`, `apk list --installed`

## Auth Zones Storage
**Primary:** `/var/lib/unbound/`
- root.zone (2.1M) - Recursion base
- arpa.zone (35K) - Reverse DNS
- in-addr.arpa.zone (215K) - IPv4 reverse
- root.hints (3.2K)
- root.key (1.2K) - DNSSEC

**Cache:** `/tmp/lib/unbound/` (symlinks for fast access)

## Auto-Update Mechanisms
1. **root.hints**: Daily check script (`check_root_hints.sh`) at 3 AM
2. **Auth zones**: Auto-updated by Unbound from ICANN servers
   - lax.xfr.dns.icann.org
   - iad.xfr.dns.icann.org
3. **unbound-anchor**: Configured for monthly DNSSEC key updates (1st day, 2 AM)
