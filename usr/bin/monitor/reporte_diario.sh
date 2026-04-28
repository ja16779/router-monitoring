#!/bin/sh
# Reporte Diario - Formato mejorado

. /etc/monitor/config.sh 2>/dev/null

FECHA=$(date '+%Y-%m-%d')
HORA=$(date '+%H:%M:%S')
HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || echo "OpenWrt")

# Sistema
UPTIME=$(cat /proc/uptime | awk '{d=int($1/86400);h=int(($1%86400)/3600);m=int(($1%3600)/60);printf "%dd %dh %dm",d,h,m}')
LOAD=$(cat /proc/loadavg | awk '{print $1}')

# Memoria
MEM_USADO=$(free | grep Mem | awk '{printf "%d", $3/1024}')
MEM_TOTAL=$(free | grep Mem | awk '{printf "%d", $2/1024}')
MEM_PCT=$(free | grep Mem | awk '{printf "%d", $3*100/$2}')

# Temperatura
TEMP="N/A"
[ -f /sys/class/thermal/thermal_zone0/temp ] && TEMP="$(cat /sys/class/thermal/thermal_zone0/temp | awk '{printf "%d", $1/1000}')"

# Internet
INET_ICON="🔴"
INET_STATUS="Desconectado"
LATENCIA="-"
if ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; then
    INET_ICON="🟢"
    INET_STATUS="Conectado"
    LATENCIA=$(ping -c 3 8.8.8.8 2>/dev/null | tail -1 | awk -F'/' '{printf "%.0f", $5}')
fi

# Conexiones
CONEXIONES=$(cat /proc/net/nf_conntrack 2>/dev/null | wc -l)

# Clientes WiFi
WIFI=0
if command -v iwinfo > /dev/null 2>&1; then
    for IFACE in $(iwinfo 2>/dev/null | grep ESSID | awk '{print $1}'); do
        CLIENTES=$(iwinfo "$IFACE" assoclist 2>/dev/null | grep -c "dBm")
        WIFI=$((WIFI + CLIENTES))
    done
fi

# Clientes DHCP
DHCP=$(wc -l < /tmp/dhcp.leases 2>/dev/null || echo 0)

# Servicios
SVC_LIST=""
SVC_OK=0
SVC_FAIL=0
for SVC in dnsmasq dropbear odhcpd; do
    if pidof "$SVC" > /dev/null 2>&1; then
        SVC_LIST="${SVC_LIST}    ✅ $SVC
"
        SVC_OK=$((SVC_OK + 1))
    else
        SVC_LIST="${SVC_LIST}    ❌ $SVC
"
        SVC_FAIL=$((SVC_FAIL + 1))
    fi
done

# Icono de temperatura
TEMP_ICON="🌡"
[ "$TEMP" != "N/A" ] && [ "$TEMP" -gt 60 ] && TEMP_ICON="🔥"

# Icono de RAM
RAM_ICON="💾"
[ "$MEM_PCT" -gt 80 ] && RAM_ICON="⚠️"

MENSAJE="📊 <b>REPORTE DIARIO</b>
━━━━━━━━━━━━━━━━━━━━
🏠 <b>$HOSTNAME</b>
📅 $FECHA  🕐 $HORA

<b>━━━ 🖥 SISTEMA ━━━</b>
⏱ Uptime: <code>$UPTIME</code>
📈 Load: <code>$LOAD</code>
$TEMP_ICON Temp: <code>${TEMP}°C</code>
$RAM_ICON RAM: <code>${MEM_USADO}MB/${MEM_TOTAL}MB (${MEM_PCT}%)</code>

<b>━━━ 🌐 RED ━━━</b>
$INET_ICON Internet: $INET_STATUS
📶 Latencia: <code>${LATENCIA}ms</code>
🔗 Conexiones: <code>$CONEXIONES</code>
📱 WiFi: <code>$WIFI</code> │ 🖥 DHCP: <code>$DHCP</code>

<b>━━━ ⚙️ SERVICIOS ━━━</b>
$SVC_LIST
✅ <code>$SVC_OK</code> activos │ ❌ <code>$SVC_FAIL</code> caídos"

/usr/bin/monitor/notificar.sh "$MENSAJE" 1

logger -t "reporte" "Reporte diario enviado"

# Salida consola (sin HTML)
echo "=== REPORTE DIARIO ==="
echo "Host: $HOSTNAME"
echo "Fecha: $FECHA $HORA"
echo "Uptime: $UPTIME | Load: $LOAD | Temp: ${TEMP}C"
echo "RAM: ${MEM_USADO}MB/${MEM_TOTAL}MB (${MEM_PCT}%)"
echo "Internet: $INET_STATUS | Latencia: ${LATENCIA}ms"
echo "Conexiones: $CONEXIONES | WiFi: $WIFI | DHCP: $DHCP"
echo "Servicios OK: $SVC_OK | Caidos: $SVC_FAIL"
