#!/bin/bash

# Router Health Check + Telegram Notification
# Ejecuta router-check cada 24 horas a las 8 AM y envía resultado a Telegram

TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="-1003951418154"
SCRIPT_PATH="/home/ja16779/Desktop/Claude/skills/router-check/router-check.py"

# Ejecutar router-check y capturar salida
RESULT=$(python3 "$SCRIPT_PATH" 2>&1)
EXIT_CODE=$?

# Determinar si fue exitoso o no
if [ $EXIT_CODE -eq 0 ]; then
    STATUS="✅ SUCCESS"
else
    STATUS="⚠️ FAILED (exit: $EXIT_CODE)"
fi

# Formatear mensaje para Telegram
MESSAGE="🔍 **Router Health Check** — $(date '+%Y-%m-%d %H:%M:%S UTC')

$STATUS

$(echo "$RESULT" | head -50)"

# Si el resultado es muy largo, truncar y avisar
if [ $(echo "$RESULT" | wc -l) -gt 50 ]; then
    MESSAGE="$MESSAGE

... (output truncated, see logs for full details)"
fi

# Enviar a Telegram
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="$MESSAGE" \
    -d parse_mode="Markdown" \
    >/dev/null 2>&1

# Log local
echo "[$(date)] Router check executed. Status: $STATUS" >> /tmp/router-check-telegram.log

exit $EXIT_CODE
