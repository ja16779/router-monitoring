#!/bin/bash

#m bot token and chat ID
BOT_TOKEN="REDACTED_BOT_TOKEN"
CHAT_ID="716542586"

# Function to send Telegram message
send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
         -d chat_id="${CHAT_ID}" \
         -d text="${message}"
}

# Function to extract the IP address from the ARP table
get_ip_address() {
    local mac="$1"
    ip=$(arp -an | grep "$mac" | awk '{print $1}' | tr -d '()')
    echo "$ip"
}

# Function to monitor real-time logs using logread
monitor_log() {
    logread -f | while read -r line; do
        if echo "$line" | grep -q "AP-STA-CONNECTED"; then
            MAC_ADDRESS=$(echo "$line" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')
            #IP_ADDRESS=$(get_ip_address "$MAC_ADDRESS")
            IP=$ip
            send_telegram_message "Device connected: MAC=$MAC_ADDRESS, IP=$IP"
        elif echo "$line" | grep -q "AP-STA-DISCONNECTED"; then
            MAC_ADDRESS=$(echo "$line" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')
            IP_ADDRESS=$(get_ip_address "$MAC_ADDRESS")
            send_telegram_message "Device disconnected: MAC=$MAC_ADDRESS, IP=$IP_ADDRESS"
        fi
    done
}

# Run the monitor function
monitor_log
