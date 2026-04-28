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

IPPUBLICA=$(curl --interface lan1 -s --connect-timeout 5 http://ifconfig.me)
[ -z "$IPPUBLICA" ] && IPPUBLICA="<no IP>"

# Solo ejecutar en eventos ifup o ifdown
# Only trigger on 'connected' or 'disconnected'
if [ "$ACTION" = "connected" ] || [ "$ACTION" = "disconnected" ]; then
    TIMESTAMP="$(date '+%A %d-%b-%Y %T')"
    hostname="$(uci get system.@system[0].hostname 2>/dev/null || echo OpenWrt)"

    send_to_telegram "\#$(echo "${hostname}" | sed 's/[^a-zA-Z0-9]//g') ${ACTION}:
\`\`\`
Time: ${TIMESTAMP}
Hostname: ${hostname}
Interface: ${INTERFACE}
Device: ${DEVICE}
IP= ${IPPUBLICA}
\`\`\`"
fi

sleep 60
/etc/script/telmexperf.sh && /etc/script/megaperf.sh
