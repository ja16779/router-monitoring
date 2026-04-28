#!/bin/sh
# ip_owner_lookup.sh - Consulta WHOIS para obtener el owner de una IP

IP="$1"
LOG="/var/log/ip_owner.log"
timestamp=$(date "+%Y-%m-%d %H:%M:%S")

if [ -z "$IP" ]; then
    echo "Uso: $0 <IP>"
    exit 1
fi

# Ejecutar whois y extraer campos relevantes
whois_output=$(whois "$IP" 2>/dev/null)

owner=$(echo "$whois_output" | grep -iE "OrgName|Organization|owner" | head -n1 | cut -d: -f2- | sed 's/^[ \t]*//')
netrange=$(echo "$whois_output" | grep -iE "NetRange|CIDR" | head -n1 | cut -d: -f2- | sed 's/^[ \t]*//')
asn=$(echo "$whois_output" | grep -i "origin" | head -n1 | awk '{print $NF}')

# Fallback si no se encontró nada
[ -z "$owner" ] && owner="Unknown"
[ -z "$netrange" ] && netrange="Unknown"
[ -z "$asn" ] && asn="Unknown"

echo "IP: $IP"
echo "Owner: $owner"
echo "NetRange: $netrange"
echo "ASN: $asn"

# Registrar en log
echo "$timestamp IP: $IP Owner: $owner NetRange: $netrange ASN: $asn" >> "$LOG"
