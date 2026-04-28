#!/bin/sh
# Notificador Telegram

. /etc/monitor/config.sh 2>/dev/null

if [ "${TELEGRAM_ACTIVO:-0}" -ne 1 ]; then
    exit 0
fi

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ "$TELEGRAM_BOT_TOKEN" = "TU_BOT_TOKEN_AQUI" ]; then
    logger -t "notificar" "Error: TELEGRAM_BOT_TOKEN no configurado"
    exit 1
fi

if [ -z "$TELEGRAM_CHAT_ID" ] || [ "$TELEGRAM_CHAT_ID" = "TU_CHAT_ID_AQUI" ]; then
    logger -t "notificar" "Error: TELEGRAM_CHAT_ID no configurado"
    exit 1
fi

MENSAJE="$1"
SILENCIOSO="${2:-0}"

if [ -z "$MENSAJE" ]; then
    echo "Uso: $0 mensaje [silencioso:0|1]"
    exit 1
fi

NOTIF="false"
[ "$SILENCIOSO" -eq 1 ] && NOTIF="true"

RESPUESTA=$(curl -s -X POST     --connect-timeout 10     --max-time 30     "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"     -d "chat_id=${TELEGRAM_CHAT_ID}"     -d "text=${MENSAJE}"     -d "parse_mode=HTML"     -d "disable_notification=${NOTIF}" 2>&1)

if echo "$RESPUESTA" | grep -q '"ok":true'; then
    logger -t "notificar" "Telegram: Mensaje enviado"
    exit 0
else
    logger -t "notificar" "Telegram: Error - $RESPUESTA"
    exit 1
fi
