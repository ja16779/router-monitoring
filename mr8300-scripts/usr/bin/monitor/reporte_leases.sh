#!/bin/sh
# Reporte de expiración de leases DHCP

. /etc/monitor/config.sh 2>/dev/null

AHORA=$(date +%s)

tiempo_restante() {
    local exp=$1
    local diff=$((exp - AHORA))
    
    if [ $diff -le 0 ]; then
        echo "EXPIRADO"
        return
    fi
    
    local dias=$((diff / 86400))
    local horas=$(((diff % 86400) / 3600))
    local mins=$(((diff % 3600) / 60))
    
    if [ $dias -gt 0 ]; then
        echo "${dias}d ${horas}h"
    elif [ $horas -gt 0 ]; then
        echo "${horas}h ${mins}m"
    else
        echo "${mins}m"
    fi
}

# Construir lista de leases
LEASES_IOT=""
LEASES_LAN=""

while read exp mac ip hostname clientid; do
    [ -z "$exp" ] && continue
    
    # Formato de expiración
    exp_fecha=$(date -d "@$exp" '+%d/%m %H:%M' 2>/dev/null)
    restante=$(tiempo_restante $exp)
    
    # Limpiar hostname
    [ -z "$hostname" ] || [ "$hostname" = "*" ] && hostname="-"
    hostname_short=$(echo "$hostname" | cut -c1-14)
    
    # Formatear línea
    linea="├ <code>$ip</code>
│  $hostname_short
│  ⏰ $exp_fecha (en $restante)"
    
    # Separar por red
    if echo "$ip" | grep -q '192.168.8.'; then
        LEASES_IOT="${LEASES_IOT}
$linea"
    elif echo "$ip" | grep -q '192.168.10.'; then
        LEASES_LAN="${LEASES_LAN}
$linea"
    fi
done < /tmp/dhcp.leases

# Contar
TOTAL_IOT=$(cat /tmp/dhcp.leases | grep -c '192.168.8.')
TOTAL_LAN=$(cat /tmp/dhcp.leases | grep -c '192.168.10.')

[ -z "$LEASES_IOT" ] && LEASES_IOT="
└ Sin clientes"
[ -z "$LEASES_LAN" ] && LEASES_LAN="
└ Sin clientes"

# Construir mensaje
MENSAJE="<b>📋 LEASES DHCP</b>
<code>━━━━━━━━━━━━━━━━━━━━━━</code>

<b>🔸 RED IOT (192.168.8.x)</b>
<i>$TOTAL_IOT dispositivos</i>$LEASES_IOT

<b>🔹 RED LAN (192.168.10.x)</b>
<i>$TOTAL_LAN dispositivos</i>$LEASES_LAN

<code>━━━━━━━━━━━━━━━━━━━━━━</code>
🕛 $(date '+%d/%m/%Y %H:%M')"

# Enviar por Telegram
curl -s -X POST     --connect-timeout 10     --max-time 30     "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"     -d "chat_id=${TELEGRAM_CHAT_ID}"     -d "text=${MENSAJE}"     -d "parse_mode=HTML"     -d "disable_notification=true" >/dev/null 2>&1

logger -t "reporte_leases" "Reporte enviado"
