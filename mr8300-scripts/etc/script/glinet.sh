#!/bin/bash

# Define GL.iNet GUI URL
GLINET_URL="http://192.168.8.1"  # Change this if your router has a different IP

# Telegram notification function
send_to_telegram() {
    logger -p local0.info -t dhcp-remove-notify "$1"
    token="REDACTED_BOT_TOKEN"
    chat_id="716542586"
    if [[ -n "${token}" ]] && [[ -n "${chat_id}" ]]; then
        curl -skim 10 --data disable_notification="false" --data parse_mode="MarkdownV2" --data chat_id="$chat_id" --data-urlencode "text=$1" "https://api.telegram.org/bot${token}/sendMessage" > /dev/null
    else
        logger -p local0.info -t wifi_connection "Error: Your Telegram chat_id or token is empty"
    fi
}

# Check if the GUI is responding
response=$(curl -s -o /dev/null -w "%{http_code}" "$GLINET_URL")

if [ "$response" -eq 200 ]; then
    message="GL.iNet GUI is working!"
    send_to_telegram "$message"
else
    message="GL.iNet GUI is not accessible! HTTP Code: $response"
fi

# Send notification to Telegram
send_to_telegram "$message"

echo "$message"
