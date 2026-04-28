#!/bin/sh
# Reporte completo de medianoche con tráfico por cliente

. /etc/monitor/config.sh 2>/dev/null

formato_bytes() {
    local bytes=$1
    [ -z "$bytes" ] || [ "$bytes" -eq 0 ] 2>/dev/null && echo "0 B" && return
    if [ $bytes -ge 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}") GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}") MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}") KB"
    else
        echo "$bytes B"
    fi
}

# === SISTEMA ===
UPTIME=$(uptime | sed 's/.*up //' | sed 's/,.*load.*//' | sed 's/, *$//' | head -c 20)
LOAD=$(cat /proc/loadavg | cut -d' ' -f1-3)
MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
MEM_USADO=$(free | grep Mem | awk '{print $3}')
MEM_PCT=$(awk "BEGIN {printf \"%.0f\", $MEM_USADO*100/$MEM_TOTAL}")
TEMP_CPU=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.1f", $1/1000}')

# === CLIENTES ===
CLIENTES_TOTAL=$(cat /tmp/dhcp.leases 2>/dev/null | wc -l)
CLIENTES_WIFI=$(for iface in wlan0 wlan0-1 wlan1 wlan1-1; do iwinfo $iface assoclist 2>/dev/null; done | grep -c 'dBm')

# === CONEXIONES ===
CONEXIONES=$(cat /proc/net/nf_conntrack 2>/dev/null | wc -l)

# === SEGURIDAD ===
SSH_INTENTOS=$(logread 2>/dev/null | grep -c 'Failed password\|Invalid user')
SSH_INTENTOS=${SSH_INTENTOS:-0}

# === INTERNET ===
ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && PING_OK="OK" || PING_OK="FALLO"

# === TRÁFICO POR CLIENTE ===
/usr/bin/monitor/traffic_accounting.sh get >/dev/null 2>&1

TRAFICO_CLIENTES=""
if [ -f /tmp/traffic_clients.dat ]; then
    while IFS='|' read ip down up hostname; do
        [ "${ip#\#}" != "$ip" ] && continue
        [ -z "$ip" ] && continue
        
        total=$((down + up))
        [ $total -lt 1024 ] && continue
        
        [ "$hostname" = "-" ] || [ -z "$hostname" ] && hostname="?"
        
        down_fmt=$(formato_bytes $down)
        up_fmt=$(formato_bytes $up)
        hostname_short=$(echo "$hostname" | cut -c1-12)
        
        TRAFICO_CLIENTES="${TRAFICO_CLIENTES}
├ <code>$ip</code> ($hostname_short)
│  ↓$down_fmt ↑$up_fmt"
    done < /tmp/traffic_clients.dat
fi

[ -z "$TRAFICO_CLIENTES" ] && TRAFICO_CLIENTES="
└ Sin tráfico significativo"

# Construir mensaje
MENSAJE="<b>🌙 REPORTE MEDIANOCHE</b>
<code>━━━━━━━━━━━━━━━━━━━━━━</code>

<b>📊 SISTEMA</b>
├ Uptime: $UPTIME
├ Load: $LOAD
├ RAM: $MEM_PCT%
└ Temp: ${TEMP_CPU}°C

<b>👥 CLIENTES</b>
├ Total: $CLIENTES_TOTAL
└ WiFi: $CLIENTES_WIFI

<b>🔗 CONEXIONES:</b> $CONEXIONES
<b>🛡 SSH fallidos:</b> $SSH_INTENTOS
<b>🌐 Internet:</b> $PING_OK

<b>📈 TRÁFICO POR CLIENTE (24h)</b>$TRAFICO_CLIENTES

<code>━━━━━━━━━━━━━━━━━━━━━━</code>
🕛 $(date '+%Y-%m-%d %H:%M:%S')"

# Enviar por Telegram
curl -s -X POST \
    --connect-timeout 10 \
    --max-time 30 \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${MENSAJE}" \
    -d "parse_mode=HTML" \
    -d "disable_notification=true" >/dev/null 2>&1

# Reiniciar contadores después del reporte
/usr/bin/monitor/traffic_accounting.sh reset >/dev/null 2>&1

logger -t "reporte_medianoche" "Reporte enviado"
