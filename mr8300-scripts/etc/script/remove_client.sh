#!/bin/sh

# === Configuration ===
TOKEN="${TG_TOKEN:-REDACTED_BOT_TOKEN}"
CHAT_ID="${TG_CHAT_ID:-716542586}"
WIFI_CLIENTS_FILE="/tmp/wifi_clients.txt"
SYSINFO_MODEL="/tmp/sysinfo/model"
DEVICE_NAME="$(tr -cd '[:alnum:]' < "$SYSINFO_MODEL")"

# === Functions ===

log_info() {
    logger -p local0.info -t dhcp-remove-notify "$1"
}

send_to_telegram() {
    local message="$1"
    if [ -n "$TOKEN" ] && [ -n "$CHAT_ID" ]; then
        curl -s --max-time 10 \
            --data disable_notification="false" \
            --data parse_mode="MarkdownV2" \
            --data chat_id="$CHAT_ID" \
            --data-urlencode "text=$message" \
            "https://api.telegram.org/bot${TOKEN}/sendMessage" > /dev/null
    else
        log_info "Error: Telegram chat_id or token is empty"
    fi
}

generate_clients_file() {
    if [ ! -f "$WIFI_CLIENTS_FILE" ]; then
        awk '{print $3,$4,$5}' /tmp/dhcp.leases > "$WIFI_CLIENTS_FILE"
    fi
}

process_client_line() {
    local ip="$1"
    local hostname="$2"
    local mac="$3"

    ping -c 1 -W 1 "$ip" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        sed -i "/$ip $hostname $mac/d" "$WIFI_CLIENTS_FILE"
        log_info "Client removed: $hostname ($ip, $mac)"
        send_to_telegram "\#$(echo "$hostname" | tr -cd '[:alnum:]') REMOVED from \#${DEVICE_NAME}:\n\`\`\`\nTime: $(date "+%A %d-%b-%Y %T")\nHostname: $hostname\nIP Address: $ip\nMAC Address: $mac\n\`\`\`"
    fi
}

main() {
    generate_clients_file
    while IFS= read -r line; do
        ip_address=$(echo "$line" | awk '{print $1}')
        hostname=$(echo "$line" | awk '{print $2}')
        mac_address=$(echo "$line" | awk '{print $3}')
        process_client_line "$ip_address" "$hostname" "$mac_address"
        sleep 1
    done < "$WIFI_CLIENTS_FILE"
}

# === Execution ===
main
