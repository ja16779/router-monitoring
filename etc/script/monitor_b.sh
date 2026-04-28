#!/bin/bash

# Your bot token and chat ID
BOT_TOKEN="REDACTED_BOT_TOKEN"
CHAT_ID="716542586"

# Function to send a message to Telegram
send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
         -d chat_id="${CHAT_ID}" \
         -d text="$message" \
         -d parse_mode="Markdown"
}

# Function to get IP address by MAC address
get_ip_address() {
    local mac="$1"
    local retries=5
    local delay=1
    local ip=""

    while [ $retries -gt 0 ]; do
        ip=$(ip neigh | grep -i "$mac" | awk '{print $1}')
        if [ -n "$ip" ]; then
            break
        fi
        sleep $delay
        retries=$((retries - 1))
    done

    echo "$ip"
}

# Function to get hostname from DHCP leases
get_hostname() {
    local mac="$1"
    local hostname
    hostname=$(grep -i "$mac" /tmp/dhcp.leases | awk '{print $4}')
    echo "${hostname:-Unknown}"
    if [ "$hostname" = "*" ]; then
    hostname="NONAME"
    fi
}

# Monitor log for station connect/disconnect events
monitor_log() {
    logread -f | while read -r line; do
        if echo "$line" | grep -q "AP-STA-CONNECTED"; then
            MAC_ADDRESS=$(echo "$line" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')
            IP_ADDRESS=$(get_ip_address "$MAC_ADDRESS")
            HOSTNAME=$(get_hostname "$MAC_ADDRESS")
            send_telegram_message "*Device Connected*\nMAC: \`$MAC_ADDRESS\`\nIP: \`$IP_ADDRESS\`\nHostname: \`$HOSTNAME\`
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
            send_telegram_message "*Device Disconnected*\nMAC: \`$MAC_ADDRESS\`\nLast known IP: \`$IP_ADDRESS\`\nHostname: \`$HOSTNAME\`"
        fi
    done
}

# Run the monitor function
monitor_log

