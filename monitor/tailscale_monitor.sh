#!/bin/sh

TELEGRAM_TOKEN="8054647573:AAE_u741UvHjf4ZcsxbTbq1e9eMdtIOBkz8"
TELEGRAM_CHAT_ID="-1003951418154"
STATE_FILE="/tmp/tailscale_monitor_state"

send_telegram() {
    curl -s --max-time 15 \
        -d "parse_mode=HTML" \
        -d "chat_id=$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" > /dev/null
}

# Obtener estado — si tailscale no responde, salir silenciosamente
TS_JSON=$(tailscale status --json 2>/dev/null)
if [ -z "$TS_JSON" ]; then
    echo "$(date): tailscale status sin respuesta, saltando"
    exit 0
fi

TS_STATE=$(echo "$TS_JSON" | jsonfilter -e '@.BackendState' 2>/dev/null)
if [ -z "$TS_STATE" ]; then
    echo "$(date): no se pudo leer BackendState, saltando"
    exit 0
fi

PREV_STATE="Running"
[ -f "$STATE_FILE" ] && PREV_STATE=$(cat "$STATE_FILE")

FECHA=$(date "+%Y-%m-%d %H:%M CST")

if [ "$TS_STATE" != "Running" ]; then
    if [ "$PREV_STATE" = "Running" ]; then
        MSG=$(printf "🔴 <b>Tailscale OFFLINE — Flint-2</b>\n<code>━━━━━━━━━━━━━━━━━━━━</code>\n⚠️ Estado: <b>%s</b>\n📅 %s\n\nRouter activo por WAN directa." "$TS_STATE" "$FECHA")
        send_telegram "$MSG"
        echo "$(date): ALERTA OFFLINE enviada (estado: $TS_STATE)"
    else
        echo "$(date): Tailscale sigue offline ($TS_STATE) - sin spam"
    fi
    echo "$TS_STATE" > "$STATE_FILE"
else
    if [ "$PREV_STATE" != "Running" ]; then
        MSG=$(printf "✅ <b>Tailscale RECUPERADO — Flint-2</b>\n<code>━━━━━━━━━━━━━━━━━━━━</code>\n🟢 Estado: Running\n📅 %s" "$FECHA")
        send_telegram "$MSG"
        echo "$(date): ALERTA RECUPERACION enviada"
    else
        echo "$(date): Tailscale OK ($TS_STATE)"
    fi
    echo "Running" > "$STATE_FILE"
fi
