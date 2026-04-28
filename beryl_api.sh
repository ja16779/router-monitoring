#!/bin/sh
echo "Content-Type: application/json"
echo ""

# Sistema
UPTIME=$(cat /proc/uptime | awk '{print $1}')
LOAD=$(cat /proc/loadavg | awk '{print $1}')
MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
MEM_USED=$(free | grep Mem | awk '{print $3}')
MEM_PCT=$(awk "BEGIN {printf \"%.0f\", $MEM_USED*100/$MEM_TOTAL}")
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.1f", $1/1000}')

# Tráfico LAN
RX_LAN=$(cat /sys/class/net/br-lan.10/statistics/rx_bytes 2>/dev/null || echo 0)
TX_LAN=$(cat /sys/class/net/br-lan.10/statistics/tx_bytes 2>/dev/null || echo 0)

# Conexión al Flint
FLINT_IP="192.168.10.1"
ping -c 1 -W 1 $FLINT_IP >/dev/null 2>&1 && FLINT_OK="true" || FLINT_OK="false"
LATENCY=$(ping -c 1 -W 1 $FLINT_IP 2>/dev/null | grep "time=" | sed 's/.*time=//' | sed 's/ .*//')
[ -z "$LATENCY" ] && LATENCY="--"

# Internet (via Flint)
ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && INET="true" || INET="false"
LAT_INET=$(ping -c 1 -W 2 1.1.1.1 2>/dev/null | grep "time=" | sed 's/.*time=//' | sed 's/ .*//')
[ -z "$LAT_INET" ] && LAT_INET="null"

# Clientes WiFi
WIFI_2G=$(iwinfo wlan0 assoclist 2>/dev/null | grep -c "dBm")
WIFI_5G=$(iwinfo wlan1 assoclist 2>/dev/null | grep -c "dBm")
WIFI_TOTAL=$((WIFI_2G + WIFI_5G))

# Lista de clientes WiFi con señal
WIFI_LIST=$(for iface in wlan0 wlan1; do
    band="2.4G"
    echo "$iface" | grep -q "wlan1" && band="5G"
    ssid=$(iwinfo $iface info 2>/dev/null | grep ESSID | cut -d'"' -f2)
    iwinfo $iface assoclist 2>/dev/null | grep "dBm" | while read mac signal rest; do
        dbm=$(echo "$signal" | grep -oE '[-0-9]+' | head -1)
        echo "{\"mac\":\"$mac\",\"signal\":$dbm,\"band\":\"$band\",\"ssid\":\"$ssid\"}"
    done
done | tr '\n' ',' | sed 's/,$//')

cat << EOF
{
  "system": {
    "uptime": $UPTIME,
    "load": $LOAD,
    "mem_pct": $MEM_PCT,
    "temp": $TEMP,
    "internet": $INET,
    "inet_latency": $LAT_INET
  },
  "connectivity": {
    "flint_ok": $FLINT_OK,
    "flint_ip": "$FLINT_IP",
    "latency": "$LATENCY"
  },
  "traffic": {
    "lan": {"rx": $RX_LAN, "tx": $TX_LAN}
  },
  "clients": {
    "wifi_total": $WIFI_TOTAL,
    "wifi_2g": $WIFI_2G,
    "wifi_5g": $WIFI_5G
  },
  "wifi_clients": [$WIFI_LIST],
  "timestamp": $(date +%s)
}
EOF
