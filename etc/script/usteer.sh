#!/bin/sh

OUTPUT="/tmp/usteer_clients.csv"
LEASES="/tmp/dhcp.leases"

echo "Interface,SSID,Channel,MAC,Signal,IP" > "$OUTPUT"

# Cache AP info (iface → ssid/channel) from usteer
# -S makes output simple: key=value lines
ubus -S call usteer get_aps '{}' | awk '
/^iface=/ {iface=$0; sub(/^iface=/,"",iface)}
/^ssid=/ {ssid=$0; sub(/^ssid=/,"",ssid)}
/^channel=/ {channel=$0; sub(/^channel=/,"",channel)}
/^$/ { if (iface!="") { print iface","ssid","channel; iface=""; ssid=""; channel="" } }
END { if (iface!="") print iface","ssid","channel }
' > /tmp/aps_cache.csv

# Function: lookup SSID, channel by iface
lookup_ap() {
    awk -F',' -v ifc="$1" '$1==ifc {print $2","$3; found=1} END {if (!found) print ",\"\""}' /tmp/aps_cache.csv
}

# Iterate clients (simple format) and build CSV
ubus -S call usteer get_clients '{}' | awk -v leases="$LEASES" '
function ip_from_mac(mac,  cmd, ip) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", mac)
    cmd = "grep -i \"" mac "\" " leases " | awk \"{print $3}\" | tail -n1"
    cmd | getline ip
    close(cmd)
    return ip
}
BEGIN {
    OFS=","
}
# Collect per-client fields
/^addr=/ {addr=$0; sub(/^addr=/,"",addr)}
/^iface=/ {iface=$0; sub(/^iface=/,"",iface)}
/^signal=/ {signal=$0; sub(/^signal=/,"",signal)}
# End of a client block is an empty line
/^$/ {
    if (addr!="") {
        ip = ip_from_mac(addr)
        print iface, "", "", addr, signal, ip
        addr=""; iface=""; signal=""
    }
}
END {
    if (addr!="") {
        ip = ip_from_mac(addr)
        print iface, "", "", addr, signal, ip
    }
}
' | while IFS=',' read iface empty1 empty2 mac signal ip; do
    apinfo=$(lookup_ap "$iface")
    ssid=$(echo "$apinfo" | cut -d',' -f1)
    channel=$(echo "$apinfo" | cut -d',' -f2)
    echo "$iface,$ssid,$channel,$mac,$signal,${ip:-}" >> "$OUTPUT"
done

echo "CSV generated at $OUTPUT"
