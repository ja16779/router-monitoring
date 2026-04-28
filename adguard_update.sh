#!/usr/bin/env bash
# Script to run on Flint-2 router via SSH

set -e

echo "=== COMMAND 1: Update AdGuard Home upstream DNS ==="
curl -s -X POST http://127.0.0.1:3000/control/dns_config \
  -H "Content-Type: application/json" \
  -d '{
    "upstream_dns": [
      "quic://dns.adguard-dns.com",
      "quic://unfiltered.adguard-dns.com",
      "https://dns.google/dns-query",
      "https://cloudflare-dns.com/dns-query",
      "[/0.openwrt.pool.ntp.org/]8.8.8.8",
      "[/1.openwrt.pool.ntp.org/]8.8.4.4"
    ],
    "upstream_mode": "fastest_addr"
  }'

echo ""
echo "=== COMMAND 2: Verify config applied ==="
curl -s http://127.0.0.1:3000/control/dns_info | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps({'upstream_dns': d.get('upstream_dns'), 'upstream_mode': d.get('upstream_mode')}, indent=2))"

echo ""
echo "=== COMMAND 3: Test DNS resolution ==="
nslookup google.com 127.0.0.1
