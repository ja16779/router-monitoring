#!/bin/sh

# Variables del entorno (set por hotplug)
ACTION="$ACTION"
INTERFACE="$INTERFACE"

# Función para enviar mensaje a Telegram
send_to_telegram() {
    MESSAGE="$1"
    logger -p local0.info -t wan-telegram-notify "$MESSAGE"

    token="REDACTED_BOT_TOKEN"
    chat_id="716542586"

    if [ -n "$token" ] && [ -n "$chat_id" ]; then
        # Escapar caracteres especiales para MarkdownV2
        escaped_message=$(echo "$MESSAGE" | sed 's/[][()_.\-!~*`>#+=|{}]/\\&/g')
        curl -s --max-time 10 \
            --data-urlencode "text=${escaped_message}" \
            --data "disable_notification=false" \
            --data "parse_mode=MarkdownV2" \
            --data "chat_id=$chat_id" \
            "https://api.telegram.org/bot${token}/sendMessage" > /dev/null
    else
        logger -p local0.info -t wan-telegram-notify "Error: chat_id o token de Telegram no definidos"
    fi
}

# Verificar si la interfaz es 'wan' y hay acción relevante
if [ "$INTERFACE" = "wan" ]; then
    TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
    if [ "$ACTION" = "ifup" ]; then
        send_to_telegram "🟢 *Interfaz WAN activada*\n\nLa interfaz \`wan\` fue levantada el *$TIMESTAMP*."
    elif [ "$ACTION" = "ifdown" ]; then
        send_to_telegram "🔴 *Interfaz WAN desactivada*\n\nLa interfaz \`wan\` fue bajada el *$TIMESTAMP*."
    fi
fi

