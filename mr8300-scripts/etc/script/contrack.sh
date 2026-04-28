#!/bin/sh
#
# Script: conntrack-names.sh
# Objetivo: listar IPs de nf_conntrack con su hostname en OpenWrt
#

LOGFILE="/var/log/conntrack-names+$(date '+%Y-%m-%d-%H:%M:%S').log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Extraer todas las IPs únicas de nf_conntrack
IPs=$(awk '{for(i=1;i<=NF;i++){if($i ~ /^src=/){split($i,a,"=");print a[2]} if($i ~ /^dst=/){split($i,a,"=");print a[2]}}}' /proc/net/nf_conntrack | sort -u)

for ip in $IPs; do
    # Resolver hostname con nslookup
    name=$(nslookup "$ip" 2>/dev/null | awk -F'= ' '/name =/ {print $2}' | sed 's/\.$//')
    if [ -n "$name" ]; then
        echo "$ip → $name"
        log "$ip → $name"
    else
        echo "$ip → (sin nombre)"
        log "$ip → (sin nombre)"
    fi
done
