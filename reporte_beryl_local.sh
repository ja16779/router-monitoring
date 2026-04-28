#!/bin/sh
# Reporte de clientes WiFi - Beryl AX

. /etc/monitor/config.sh 2>/dev/null

UPTIME=$(uptime | sed 's/.*up //' | sed 's/,.*load.*//')
MEM=$(free | grep Mem | awk '{printf "%d", $3*100/$2}')

WIFI_2G=$(iwinfo wlan0 assoclist 2>/dev/null)
WIFI_5G=$(iwinfo wlan1 assoclist 2>/dev/null)

COUNT_2G=$(echo "$WIFI_2G" | grep -c "dBm")
COUNT_5G=$(echo "$WIFI_5G" | grep -c "dBm")
TOTAL=$((COUNT_2G + COUNT_5G))

LISTA_2G=""
if [ "$COUNT_2G" -gt 0 ]; then
    LISTA_2G=$(echo "$WIFI_2G" | grep "dBm" | while read mac dbm rest; do
        signal=$(echo "$dbm" | grep -oE '[-0-9]+')
        echo "${signal}dBm $mac"
    done | head -10)
fi
[ -z "$LISTA_2G" ] && LISTA_2G="Sin clientes"

LISTA_5G=""
if [ "$COUNT_5G" -gt 0 ]; then
    LISTA_5G=$(echo "$WIFI_5G" | grep "dBm" | while read mac dbm rest; do
        signal=$(echo "$dbm" | grep -oE '[-0-9]+')
        echo "${signal}dBm $mac"
    done | head -10)
fi
[ -z "$LISTA_5G" ] && LISTA_5G="Sin clientes"

FECHA=$(date '+%d/%m/%Y %H:%M')

MENSAJE="<b>BERYL AX - WiFi</b>
<code>--------------------</code>
Uptime: $UPTIME
RAM: ${MEM}%

<b>2.4 GHz ($COUNT_2G)</b>
<pre>$LISTA_2G</pre>

<b>5 GHz ($COUNT_5G)</b>
<pre>$LISTA_5G</pre>

<b>Total: $TOTAL clientes</b>
<code>--------------------</code>
$FECHA"

curl -s -X POST \
    --connect-timeout 10 \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${MENSAJE}" \
    -d "parse_mode=HTML" \
    -d "disable_notification=true" >/dev/null 2>&1

logger -t "reporte_wifi" "Reporte enviado"
