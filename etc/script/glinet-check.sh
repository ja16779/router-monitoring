#!/bin/sh

# Define your Telegram bot token, chat ID, and URL
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"


# Function to send messages via Telegram
send_to_telegram() {
    local message="$1"
    curl -s -X POST "$URL" -d chat_id="$ID" -d text="$message"
}

# Define GL.iNet GUI URL
GLINET_URL="http://192.168.8.1"  # Change this if your router has a different IP


hostname=$(uname -n)

# Check if the GUI is responding
response=$(curl -s -o /dev/null -w "%{http_code}" "$GLINET_URL")

if [ "$response" -eq 200 ]; then
    message1="GL.iNet GUI is working!"
else
    message="GL.iNet GUI is not accessible! HTTP Code: $response"
 send_to_telegram "\#$(echo "${hostname}" | sed 's/[^a-zA-Z0-9]//g')\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Hostname: ${hostname}
GUI : $message
\`\`\`"

fi

# Send notification to Telegram
#send_to_telegram "$message"

echo "$message1"
echo "$message"
