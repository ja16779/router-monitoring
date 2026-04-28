#!/bin/sh

# Define Telegram bot token, chat ID, and API URL
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
TELEGRAM_URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# Function to send a Telegram message
send_telegram_message() {
    local message="$1"
    curl -s -X POST "$TELEGRAM_URL" -d chat_id="$ID" -d text="$message"
}

# Target URL for checking internet
INTERNET_CHECK_URL="http://ifconfig.me"

# Network Interface
INTERFACE="192.168.100.4"
PROVEEDOR="Mega"

# Check internet using curl
curl --interface "$INTERFACE" --silent --connect-timeout 5 "$INTERNET_CHECK_URL" > /dev/null

# Verify exit status and send a message
if [ $? -eq 0 ]; then
    STATUS_MSG="$(uname -n): Internet connection is UP on $INTERFACE $PROVEEDOR"
else
    STATUS_MSG="$(uname -n): Internet connection is DOWN on $INTERFACE $PROVEEDOR"
fi

# Send notification to Telegram
send_telegram_message "$STATUS_MSG"
