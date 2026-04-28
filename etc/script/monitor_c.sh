#!/bin/bash

BOT_TOKEN="REDACTED_BOT_TOKEN"
CHAT_ID="716542586"


send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
         -d chat_id="${CHAT_ID}" \
         -d text="$message" \
         -d parse_mode="Markdown"
}

get_ip_address() {
    local mac="$1"
    local retries=5
    local delay=1
    local ip=""

    while [ $retries -gt 0 ]; do
        ip=$(ip neigh | grep -i "$mac" | awk '{print $1}')
        [ -n "$ip" ] && break
        sleep $delay
        retries=$((retries - 1))
    done

    echo "$ip"
}

get_hostname() {
    local mac="$1"
    local hostname
    hostname=$(grep -i "$mac" /tmp/dhcp.leases | awk '{print $4}')
    if [ "$hostname" = "*" ] || [ -z "$hostname" ]; then
        hostname="NONAME"
    fi
    echo "$hostname"
}

monitor_log() {
    logread -f | while read -r line; do
        if echo "$line" | grep -q "AP-STA-CONNECTED"; then
            MAC_ADDRESS=$(echo "$line" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')
            IP_ADDRESS=$(get_ip_address "$MAC_ADDRESS")
            HOSTNAME=$(get_hostname "$MAC_ADDRESS")

            send_telegram_message "\#$(echo "${HOSTNAME}" | sed 's/[^a-zA-Z0-9]//g') Connected:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Hostname: ${HOSTNAME}
IP Address: ${IP_ADDRESS}
MAC Address: ${MAC_ADDRESS}
\`\`\`"
        elif echo "$line" | grep -q "AP-STA-DISCONNECTED"; then
            MAC_ADDRESS=$(echo "$line" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')
            IP_ADDRESS=$(get_ip_address "$MAC_ADDRESS")
            HOSTNAME=$(get_hostname "$MAC_ADDRESS")

            send_telegram_message "\#$(echo "${HOSTNAME}" | sed 's/[^a-zA-Z0-9]//g') Disconnected:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Hostname: ${HOSTNAME}
IP Address: ${IP_ADDRESS}
MAC Address: ${MAC_ADDRESS}
\`\`\`"
        fi
    done
}

monitor_log

