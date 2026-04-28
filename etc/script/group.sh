#!/bin/sh

# Function to send notifications to Telegram group
send_to_group() {
    logger -p local0.info -t dhcp-group-notify "$1"
    token="REDACTED_BOT_TOKEN"  # Replace with your actual bot token
    group_id="-716542586"  # Use the group's chat ID (note: group IDs usually start with a '-' sign)
    if [[ -n "${token}" ]] && [[ -n "${group_id}" ]]; then
        curl -s --max-time 10 --data disable_notification="false" \
            --data parse_mode="MarkdownV2" \
            --data chat_id="$group_id" \
            --data-urlencode "text=$1" \
            "https://api.telegram.org/bot${token}/sendMessage" > /dev/null || \
            logger -p local0.err -t dhcp-group-notify "Telegram group notification failed"
    else
        logger -p local0.err -t dhcp-group-notify "Error: Telegram group_id or token is empty"
    fi
}

IFS=$IFS
online_devices=""
offline_devices=""
while read time mac ip name bs; do
    if ping -c1 "$ip" &>/dev/null; then
        online_devices="${online_devices}\nDevice: $name\nMAC: $mac\nIP: $ip\nStatus: online\n"
    else
        offline_devices="${offline_devices}\nDevice: $name\nMAC: $mac\nIP: $ip\nStatus: offline\n"
    fi
done < /tmp/dhcp.leases > /tmp/device-status.tmp

# Format messages
online_message="\#Online_Devices:\n\`\`\`\n$(date "+%A %d-%b-%Y %T")\n$online_devices\`\`\`"
offline_message="\#Offline_Devices:\n\`\`\`\n$(date "+%A %d-%b-%Y %T")\n$offline_devices\`\`\`"

# Send messages to the group
send_to_group "$online_message"
send_to_group "$offline_message"

# Save the final output
cp /tmp/device-status.tmp /tmp/device-status.out
