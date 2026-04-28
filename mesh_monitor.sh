#!/bin/sh
# mesh_monitor.sh — Notifica por Telegram cuando el mesh 802.11s sube o baja
# Cron: * * * * * /etc/script/mesh_monitor.sh

IFACE="phy1-mesh0"
STATE_FILE="/tmp/mesh_monitor_state"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"
LOGTAG="mesh-monitor"

send_telegram() {
    curl -skim 10 \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

# Verificar si la interfaz existe
if ! iw dev "$IFACE" info >/dev/null 2>&1; then
    exit 0
fi

# Obtener peers actuales
STATION=$(iw dev "$IFACE" station dump 2>/dev/null)
PEER_MAC=$(echo "$STATION" | grep "^Station" | awk '{print $2}')

if [ -n "$PEER_MAC" ]; then
    SIGNAL=$(echo "$STATION" | grep "signal:" | head -1 | awk '{print $2}')
    TX=$(echo "$STATION" | grep "tx bitrate:" | head -1 | grep -oE '[0-9.]+ MBit/s' | head -1)
    CURRENT="up"
else
    CURRENT="down"
fi

# Leer estado anterior
PREVIOUS=$(cat "$STATE_FILE" 2>/dev/null)

# Primera ejecucion: solo guardar estado sin notificar
if [ -z "$PREVIOUS" ]; then
    echo "$CURRENT" > "$STATE_FILE"
    exit 0
fi

# Sin cambio: salir
[ "$CURRENT" = "$PREVIOUS" ] && exit 0

# Cambio detectado: notificar y actualizar estado
echo "$CURRENT" > "$STATE_FILE"
logger -t "$LOGTAG" "Mesh $IFACE: $PREVIOUS -> $CURRENT ${PEER_MAC:+peer=$PEER_MAC}"

HOSTNAME=$(cat /proc/sys/kernel/hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ "$CURRENT" = "up" ]; then
    send_telegram "<b>#${HOSTNAME} Mesh UP ✅</b>
<pre>
Interfaz: ${IFACE}
Peer:     ${PEER_MAC}
Señal:    ${SIGNAL} dBm
TX:       ${TX}
Hora:     ${TIMESTAMP}
</pre>"
else
    send_telegram "<b>#${HOSTNAME} Mesh DOWN ❌</b>
<pre>
Interfaz: ${IFACE}
Hora:     ${TIMESTAMP}
</pre>"
fi
