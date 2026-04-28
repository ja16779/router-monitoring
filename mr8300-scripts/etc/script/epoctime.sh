#!/bin/sh

# Function to send messages to Telegram
send_to_telegram() {
    logger -p local0.info -t dhcp-join-notify "$1"
    token="REDACTED_BOT_TOKEN"  # Telegram Bot token
    chat_id="716542586"  # Telegram Chat ID
    if [ -n "${token}" ] && [ -n "${chat_id}" ]; then
        curl -s --data disable_notification="false" --data parse_mode="MarkdownV2" --data chat_id="$chat_id" \
        --data-urlencode "text=$1" "https://api.telegram.org/bot${token}/sendMessage" > /dev/null
    else
        logger -p local0.info -t dhcp-join-notify "Error: Telegram chat_id or token is empty"
    fi
}

# Input file path
input_file="/tmp/dhcp.leases"

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    logger -p local0.info -t dhcp-join-notify "Error: dhcp.leases file not found."
    exit 1
fi

# Process the input file and send messages
while IFS= read -r line; do
    # Extract fields: epoch time, MAC address, IP address, and hostname
    epoch_time=$(echo "$line" | awk '{print $1}')
    mac_address=$(echo "$line" | awk '{print $2}')
    ip_address=$(echo "$line" | awk '{print $3}')
    hostname=$(echo "$line" | awk '{print $4}')
    
    # Ensure hostname is not empty
    [ -z "$hostname" ] && hostname="NOHOSTNAME"
    
    # Convert epoch to human-readable time
    if echo "$epoch_time" | grep -qE '^[0-9]+$'; then
        human_time=$(date -d @"$epoch_time" +"%Y-%m-%d %H:%M:%S")
        
        # Prepare the message
        message="Time: $human_time\nMAC: $mac_address\nIP: $ip_address\nHostname: $hostname"
        
        # Send the message to Telegram
        send_to_telegram "\#$(echo "${hostname}" | sed 's/[^a-zA-Z0-9]//g'):
\`\`\`\
Time: ${human_time}
Hostname: ${hostname}
IP Address: ${ip_address}
MAC Address: ${mac_address}\`\`\`"

    fi
done < "$input_file"

logger -p local0.info -t dhcp-join-notify "Messages sent to Telegram."
