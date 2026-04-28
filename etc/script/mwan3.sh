#!/bin/sh

# Variables hotplug
ACTION="$ACTION"
INTERFACE="$INTERFACE"
DEVICE="$DEVICE"
HOSTNAME="$(uci get system.@system[0].hostname 2>/dev/null || echo OpenWrt)"

token="REDACTED_BOT_TOKEN"
chat_id="716542586"
URL="https://api.telegram.org/bot$token/sendMessage"

send_to_telegram() {
    logger -p local0.info -t dhcp-remove-notify "$1"
    token="REDACTED_BOT_TOKEN"
    chat_id="716542586"
    if [[ -n "${token}" ]] && [[ -n "${chat_id}" ]]; then
        curl -skim 10 --data disable_notification="false" --data parse_mode="MarkdownV2" --data chat_id="$chat_id" --data-urlencode "text=$1" "https://api.telegram.org/bot${token}/sendMessage" > /dev/null
    else
        logger -p local0.info -t wifi_connection "Error: Your telegram chat_id or token is empty"
    fi
}


# Solo ejecutar en eventos ifup o ifdown
if [ "$ACTION" = "connected" ] || [ "$ACTION" = "disconnected" ]; then
    TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
    MSG="🔔 *Evento de red detectado*\n\n*Interfaz:* \`$INTERFACE\`\n*Dispositivo:* \`$DEVICE\`\n*Acción:* \`$ACTION\`\n*Host:* \`$HOSTNAME\`\n*Hora:* $TIMESTAMP"

    MSG1="Prueba"
    curl -s -X POST $URL -d chat_id=$chat_id -d text="$MSG" /dev/null

    # Enviar mensaje Telegram
    send_to_telegram "$MSG"

fi

sleep 60
/etc/script/telmexperf.sh && /etc/script/megaperf.sh
