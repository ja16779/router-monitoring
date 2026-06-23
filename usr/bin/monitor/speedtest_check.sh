#!/bin/sh
# speedtest_check.sh v10 - Fix: binding de interfaz correcto por WAN

. /etc/monitor/config.sh 2>/dev/null

INTERFACE="${1:-wan}"
WAIT_TIME="${2:-30}"
TMPFILE="/tmp/speedtest_output_${INTERFACE}.txt"

if [ "$INTERFACE" = "wan" ]; then
    THRESHOLD="350"
    INTERFACE_NAME="Telmex"
else
    THRESHOLD="210"
    INTERFACE_NAME="Megacable"
fi

logger -t speedtest "[$INTERFACE_NAME] Iniciando speedtest..."
sleep "$WAIT_TIME"

# Validar WAN online
if ! mwan3 status 2>/dev/null | grep -q "interface $INTERFACE.*online"; then
    logger -t speedtest "[$INTERFACE_NAME] ERROR: WAN offline"
    send_telegram "❌ Speedtest cancelado - $INTERFACE_NAME offline" "MWAN3" 2>/dev/null
    exit 1
fi

# Obtener device e IP de la interfaz WAN dinámicamente
WAN_DEV=$(uci get network.${INTERFACE}.device 2>/dev/null || uci get network.${INTERFACE}.ifname 2>/dev/null)
WAN_IP=$(ip -4 addr show dev "$WAN_DEV" 2>/dev/null | grep -o 'inet [0-9.]*' | cut -d' ' -f2)

if [ -z "$WAN_DEV" ] || [ -z "$WAN_IP" ]; then
    logger -t speedtest "[$INTERFACE_NAME] ERROR: No se pudo obtener device/IP de $INTERFACE"
    send_telegram "❌ Speedtest error - no se obtuvo IP de $INTERFACE_NAME" "MWAN3" 2>/dev/null
    exit 1
fi

logger -t speedtest "[$INTERFACE_NAME] Ejecutando speedtest via $WAN_DEV ($WAN_IP) (timeout 120s)..."
rm -f "$TMPFILE"

/etc/script/speedtest -f json --accept-license --accept-gdpr -I "$WAN_DEV" > "$TMPFILE" 2>&1 &
SPEED_PID=$!

COUNTER=0
while kill -0 $SPEED_PID 2>/dev/null && [ $COUNTER -lt 120 ]; do
    sleep 1
    COUNTER=$((COUNTER + 1))
done

if kill -0 $SPEED_PID 2>/dev/null; then
    kill -9 $SPEED_PID 2>/dev/null
    logger -t speedtest "[$INTERFACE_NAME] TIMEOUT: speedtest abortado"
    send_telegram "⏱️ Timeout - Speedtest en $INTERFACE_NAME tardó >120s" "MWAN3" 2>/dev/null
    rm -f "$TMPFILE"
    exit 1
fi

# Buscar resultado
SPEEDTEST_JSON=$(grep '"type":"result"' "$TMPFILE" | tail -1)

if [ -z "$SPEEDTEST_JSON" ]; then
    logger -t speedtest "[$INTERFACE_NAME] Sin resultado JSON"
    RAW=$(cat "$TMPFILE" 2>/dev/null | head -5)
    logger -t speedtest "[$INTERFACE_NAME] Raw: $RAW"
    send_telegram "❌ Speedtest sin resultado - $INTERFACE_NAME" "MWAN3" 2>/dev/null
    rm -f "$TMPFILE"
    exit 1
fi

# Parsear
DL_BPS=$(echo "$SPEEDTEST_JSON" | grep -o '"download":{"bandwidth":[0-9]*' | cut -d: -f3)
UL_BPS=$(echo "$SPEEDTEST_JSON" | grep -o '"upload":{"bandwidth":[0-9]*' | cut -d: -f3)
PING=$(echo "$SPEEDTEST_JSON" | grep -o '"latency":[0-9.]*' | head -1 | cut -d: -f2)
ISP=$(echo "$SPEEDTEST_JSON" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)
EXT_IP=$(echo "$SPEEDTEST_JSON" | grep -o '"externalIp":"[^"]*"' | cut -d'"' -f4)

if [ -z "$DL_BPS" ] || [ "$DL_BPS" = "0" ]; then
    logger -t speedtest "[$INTERFACE_NAME] Error al parsear"
    rm -f "$TMPFILE"
    exit 1
fi

DL_MBPS=$(echo "$DL_BPS" | awk '{printf "%.1f", $1*8/1000000}')
UL_MBPS=$(echo "$UL_BPS" | awk '{printf "%.1f", $1*8/1000000}')
PING_R=$(echo "$PING" | awk '{printf "%.1f", $1}')
DL_INT=$(echo "$DL_MBPS" | cut -d. -f1)
RESULT_URL=$(echo "$SPEEDTEST_JSON" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)

logger -t speedtest "[$INTERFACE_NAME] ISP:$ISP IP:$EXT_IP DL:${DL_MBPS}M UL:${UL_MBPS}M Ping:${PING_R}ms"

if [ "$DL_INT" -lt "$THRESHOLD" ]; then
    MSG="🔴 <b>ALERTA Speedtest - $INTERFACE_NAME</b>
📥 <b>${DL_MBPS}</b> Mbps (Umbral: ${THRESHOLD}M)
📤 <b>${UL_MBPS}</b> Mbps
⏱️ ${PING_R}ms
🌐 $ISP ($EXT_IP)
🔗 ${RESULT_URL}"
    logger -t speedtest "[$INTERFACE_NAME] ⚠️ ALERTA: Speed bajo (${DL_MBPS}M < ${THRESHOLD}M)"
    send_telegram "$MSG" "MWAN3" 2>/dev/null
else
    logger -t speedtest "[$INTERFACE_NAME] ✅ OK: ${DL_MBPS}M >= ${THRESHOLD}M via $ISP"
fi

rm -f "$TMPFILE"
exit 0
