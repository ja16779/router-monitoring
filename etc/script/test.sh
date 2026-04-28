#!/bin/sh
# Clean /tmp/dhcp.leases to only online clients — safely
# Format assumed: expiry mac ip hostname clientid

LEASE_FILE="/tmp/dhcp.leases"
TMP_FILE="/tmp/dhcp.leases.online"
LOG_FILE="/var/log/dhcp_clean.log"

# Safety: require readable leases file with content
if [ ! -s "$LEASE_FILE" ]; then
  echo "$(date) - WARN: $LEASE_FILE missing or empty; aborting" >> "$LOG_FILE"
  exit 1
fi

# Discover alive IPs using layered methods:
# 1) fping (fast), 2) ping (portable), 3) arping (same-subnet MAC check)
alive_ips_file="/tmp/alive_ips.$$"
> "$alive_ips_file"

# Extract unique IPs
ips=$(awk 'NF>=3 {print $3}' "$LEASE_FILE" | sort -u)

# Try fping first
if command -v fping >/dev/null 2>&1; then
  # -a: show alive only, -t: timeout ms, -q: quiet summary
  echo "$ips" | xargs -r fping -a -t 500 2>/dev/null >> "$alive_ips_file"
fi

# Fallback to ping for any IP not yet marked alive
for ip in $ips; do
  if ! grep -qx "$ip" "$alive_ips_file"; then
    if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
      echo "$ip" >> "$alive_ips_file"
    fi
  fi
done

# Optional: arping for same-subnet confirmation (catches ICMP-blocked hosts)
if command -v arping >/dev/null 2>&1; then
  # Detect default interface
  IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
  for ip in $ips; do
    if ! grep -qx "$ip" "$alive_ips_file"; then
      # -c 1: one ARP probe, -w 1: 1s timeout, -I iface
      if [ -n "$IFACE" ] && arping -c 1 -w 1 -I "$IFACE" "$ip" >/dev/null 2>&1; then
        echo "$ip" >> "$alive_ips_file"
      fi
    fi
  done
fi

# Deduplicate alive IPs
sort -u -o "$alive_ips_file" "$alive_ips_file"

# Build filtered leases into TMP_FILE
> "$TMP_FILE"
while read -r line; do
  ip=$(echo "$line" | awk '{print $3}')
  if [ -n "$ip" ] && grep -qx "$ip" "$alive_ips_file"; then
    echo "$line" >> "$TMP_FILE"
  fi
done < "$LEASE_FILE"

# Safety: only replace if we found any alive clients
if [ -s "$TMP_FILE" ]; then
  mv "$TMP_FILE" "$LEASE_FILE"
  kept=$(wc -l < "$LEASE_FILE")
  echo "$(date) - INFO: Cleaned dhcp.leases; kept $kept online clients" >> "$LOG_FILE"
else
  rm -f "$TMP_FILE"
  echo "$(date) - WARN: No online clients detected; original preserved" >> "$LOG_FILE"
fi

rm -f "$alive_ips_file"
