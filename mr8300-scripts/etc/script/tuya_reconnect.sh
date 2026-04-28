#!/bin/sh
# Fuerza reconexión de focos Tuya después de que internet regresa
# Bloquea temporalmente el tráfico de los focos para forzar timeout TCP
# y que el firmware Tuya reconecte a la nube automáticamente

LOGTAG="tuya-reconnect"
LOCKFILE="/tmp/tuya_reconnect.lock"
TUYA_SERVER="47.251.49.30"
TUYA_PORT="8815"
WAIT_INTERNET=60
BLOCK_TIME=10
CHECK_WAIT=60
MAX_RETRIES=3

# IPs de los focos Surplife (Tuya)
BULBS="192.168.8.201 192.168.8.239 192.168.8.236"
BULB_NAMES="FCOMEDOR FTV FESCALERA"

# Telegram
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"

send_telegram() {
    curl -skim 10 \
        --data disable_notification="true" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

log() {
    logger -t "$LOGTAG" "$1"
}

# Verificar si un foco tiene conexión activa a Tuya
check_tuya_conn() {
    local ip="$1"
    grep -q "src=$ip dst=$TUYA_SERVER.*dport=$TUYA_PORT" /proc/net/nf_conntrack 2>/dev/null
}

# Obtener nombre del foco por IP
get_name() {
    local ip="$1"
    local i=1
    for b in $BULBS; do
        if [ "$b" = "$ip" ]; then
            echo "$BULB_NAMES" | awk "{print \$$i}"
            return
        fi
        i=$((i + 1))
    done
    echo "$ip"
}

# Evitar ejecuciones paralelas
if [ -f "$LOCKFILE" ]; then
    pid=$(cat "$LOCKFILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
        log "Ya hay una instancia ejecutándose (PID $pid)"
        exit 0
    fi
    rm -f "$LOCKFILE"
fi
echo $$ > "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT
WAIT_INTERNET=${WAIT_OVERRIDE:-$WAIT_INTERNET}
log "Esperando ${WAIT_INTERNET}s para estabilizar..."
sleep "$WAIT_INTERNET"

# Verificar que internet realmente funciona
if ! ping -c2 -W3 8.8.8.8 >/dev/null 2>&1; then
    log "Internet aún no estable, abortando"
    exit 1
fi

# Verificar qué focos necesitan reconexión
DISCONNECTED=""
for ip in $BULBS; do
    name=$(get_name "$ip")
    if check_tuya_conn "$ip"; then
        log "$name ($ip) ya conectado a Tuya"
    else
        log "$name ($ip) SIN conexión a Tuya"
        DISCONNECTED="$DISCONNECTED $ip"
    fi
done

# Si todos están conectados, no hacer nada
if [ -z "$DISCONNECTED" ]; then
    log "Todos los focos conectados a Tuya, nada que hacer"
    exit 0
fi

# Intentar reconexión
retry=0
while [ $retry -lt $MAX_RETRIES ] && [ -n "$DISCONNECTED" ]; do
    retry=$((retry + 1))
    log "Intento $retry/$MAX_RETRIES - Bloqueando tráfico de focos desconectados..."

    # Crear regla nftables temporal para bloquear los focos
    for ip in $DISCONNECTED; do
        nft add rule inet fw4 forward ip saddr "$ip" counter drop comment \"tuya_reconnect\" 2>/dev/null
        nft add rule inet fw4 forward ip daddr "$ip" counter drop comment \"tuya_reconnect\" 2>/dev/null
    done

    log "Tráfico bloqueado por ${BLOCK_TIME}s..."
    sleep "$BLOCK_TIME"

    # Limpiar conntrack de los focos
    for ip in $DISCONNECTED; do
        conntrack -D -s "$ip" 2>/dev/null
        conntrack -D -d "$ip" 2>/dev/null
    done

    # Remover reglas de bloqueo
    nft -a list chain inet fw4 forward 2>/dev/null | grep "tuya_reconnect" | \
        grep -oE handle [0-9]+ | awk {print } | while read handle; do
        nft delete rule inet fw4 forward handle "$handle" 2>/dev/null
    done

    log "Bloqueo removido, esperando ${CHECK_WAIT}s para reconexión..."
    sleep "$CHECK_WAIT"

    # Verificar reconexión
    STILL_DOWN=""
    for ip in $DISCONNECTED; do
        name=$(get_name "$ip")
        if check_tuya_conn "$ip"; then
            log "$name ($ip) reconectado a Tuya"
        else
            log "$name ($ip) aún desconectado"
            STILL_DOWN="$STILL_DOWN $ip"
        fi
    done
    DISCONNECTED="$STILL_DOWN"
done

# Construir reporte
TIMESTAMP=$(date +%Y-%m-%d %H:%M:%S)
RECONNECTED=""
FAILED=""

for ip in $BULBS; do
    name=$(get_name "$ip")
    if check_tuya_conn "$ip"; then
        RECONNECTED="${RECONNECTED}\n  ✓ ${name}"
    else
        FAILED="${FAILED}\n  ✗ ${name}"
    fi
done

MSG="<b>💡 Tuya Reconnect</b>
━━━━━━━━━━━━━━━━━━━━"

if [ -n "$RECONNECTED" ]; then
    MSG="${MSG}
<b>Conectados:</b><pre>$(printf "$RECONNECTED")</pre>"
fi

if [ -n "$FAILED" ]; then
    MSG="${MSG}
<b>Fallidos:</b><pre>$(printf "$FAILED")</pre>"
fi

MSG="${MSG}
🕐 $TIMESTAMP"

#send_telegram "$MSG"
log "Proceso completado"
