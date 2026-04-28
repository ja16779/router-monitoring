#!/bin/sh
# Reporte de clientes WiFi del Beryl AX

. /etc/monitor/config.sh 2>/dev/null

BERYL_IP="192.168.10.2"

INFO=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@$BERYL_IP "uptime; free | grep Mem" 2>/dev/null)
WIFI_2G=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$BERYL_IP "iwinfo wlan0 assoclist 2>/dev/null" 2>/dev/null)
WIFI_5G=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$BERYL_IP "iwinfo wlan1 assoclist 2>/dev/null" 2>/dev/null)

if [ -z "$INFO" ]; then
    MENSAJE="<b>BERYL AX</b>%0A No se pudo conectar ($BERYL_IP)"
else
    UPTIME=$(echo "$INFO" | head -1 | sed 's/.*up //' | sed 's/,.*load.*//')

    COUNT_2G=$(echo "$WIFI_2G" | grep -c "dBm")
    COUNT_5G=$(echo "$WIFI_5G" | grep -c "dBm")
    TOTAL=$((COUNT_2G + COUNT_5G))

    LISTA_2G=""
    if [ "$COUNT_2G" -gt 0 ]; then
        LISTA_2G=$(echo "$WIFI_2G" | grep "dBm" | while read mac dbm rest; do
            signal=$(echo "$dbm" | grep -oE '[-0-9]+')
            name=$(grep -i "$mac" /tmp/dhcp.leases 2>/dev/null | awk '{print $4}')
            [ -z "$name" ] || [ "$name" = "*" ] && name="-"
            echo "${signal}dBm $name"
        done | head -10)
    fi
    [ -z "$LISTA_2G" ] && LISTA_2G="Sin clientes"

    LISTA_5G=""
    if [ "$COUNT_5G" -gt 0 ]; then
        LISTA_5G=$(echo "$WIFI_5G" | grep "dBm" | while read mac dbm rest; do
            signal=$(echo "$dbm" | grep -oE '[-0-9]+')
            name=$(grep -i "$mac" /tmp/dhcp.leases 2>/dev/null | awk '{print $4}')
            [ -z "$name" ] || [ "$name" = "*" ] && name="-"
            echo "${signal}dBm $name"
        done | head -10)
    fi
    [ -z "$LISTA_5G" ] && LISTA_5G="Sin clientes"

    FECHA=$(date '+%d/%m/%Y %H:%M')

    MENSAJE="<b>BERYL AX - WiFi</b>
<code>--------------------</code>
Uptime: $UPTIME

<b>2.4 GHz ($COUNT_2G)</b>
<pre>$LISTA_2G</pre>

<b>5 GHz ($COUNT_5G)</b>
<pre>$LISTA_5G</pre>

<b>Total: $TOTAL clientes</b>
<code>--------------------</code>
$FECHA"
fi

curl -s -X POST \
    --connect-timeout 10 \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${MENSAJE}" \
    -d "parse_mode=HTML" \
    -d "disable_notification=true" >/dev/null 2>&1

logger -t "reporte_beryl" "Reporte WiFi Beryl enviado"
