#!/bin/sh
# Chequeo periódico de conexión Tuya para focos Surplife
# Se ejecuta por cron cada 10 min, solo actúa si detecta desconexión

LOGTAG="tuya-check"
TUYA_PORT="8815"
BULBS="192.168.8.201 192.168.8.239 192.168.8.236"

# Verificar si alguno está desconectado
DISCONNECTED=0
for ip in $BULBS; do
    if ! grep -q "src=$ip.*dport=$TUYA_PORT" /proc/net/nf_conntrack 2>/dev/null; then
        DISCONNECTED=1
        logger -t "$LOGTAG" "$ip sin conexión Tuya, lanzando reconexión"
        break
    fi
done

# Si todos están conectados, no hacer nada
[ "$DISCONNECTED" -eq 0 ] && exit 0

# Verificar que no haya ya una reconexión en curso
if [ -f /tmp/tuya_reconnect.lock ]; then
    pid=$(cat /tmp/tuya_reconnect.lock 2>/dev/null)
    kill -0 "$pid" 2>/dev/null && exit 0
fi

# Lanzar reconexión
logger -t "$LOGTAG" "Foco(s) desconectado(s), lanzando tuya_reconnect.sh"
WAIT_OVERRIDE=5 /etc/script/tuya_reconnect.sh &
