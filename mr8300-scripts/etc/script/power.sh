#!/bin/sh

# Threshold temperature in Celsius
THRESHOLD=65

# Telegram Bot Token and Chat ID
#TOKEN="REDACTED_BOT_TOKEN"
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# Check the current temperature
MESSAGE=$(iwinfo | grep Tx-Power)

# Compare with the threshold and send a notification if necessary
    curl -s -X POST $URL -d chat_id=$ID -d text="$MESSAGE" > /dev/null
