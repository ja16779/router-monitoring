#!/bin/sh

### Function to send notifications to Telegram
send_to_telegram() {
    logger -p local0.info -t dhcp-remove-notify "$1"
    token="REDACTED_BOT_TOKEN"
    chat_id="716542586"

    if [ -n "${token}" ] && [ -n "${chat_id}" ]; then
        curl -s --max-time 10 --data-urlencode "disable_notification=false" \
            --data-urlencode "parse_mode=MarkdownV2" \
            --data-urlencode "chat_id=${chat_id}" \
            --data-urlencode "text=$1" \
            "https://api.telegram.org/bot${token}/sendMessage" > /dev/null
    else
        logger -p local0.info -t dhcp-remove-notify "Error: Telegram chat_id or token is empty"
    fi
}

### Ensure DHCP lease file exists
if [ ! -f /tmp/dhcp.leases ]; then
    logger -p local0.error -t dhcp-remove-notify "Error: DHCP lease file not found!"
    exit 1
fi

### Initialize client list if missing
if [ ! -f /tmp/wifi_clients.txt ]; then
    awk '{print $3,$4,$5}' /tmp/dhcp.leases > /tmp/wifi_clients.txt
fi

### Get sanitized device name
device_name=$(cat /tmp/sysinfo/model | tr -dc '[:alnum:]')

### Process each client
while read -r line; do
    ip_address=$(echo "${line}" | awk '{print $1}')
    hostname=$(echo "${line}" | awk '{print $2}')
    mac_address=$(echo "${line}" | awk '{print $3}')

    ping -c 1 -W 2 "${ip_address}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then  # If client is DISCONNECTED
        sed -i "/${ip_address} ${hostname} ${mac_address}/d" /tmp/wifi_clients.txt
        local_msg="Device REMOVED: ${hostname} (${ip_address})"
        logger -p local0.info -t dhcp-remove-notify "$local_msg"

        send_to_telegram "\#$(echo "${hostname}" | tr -dc '[:alnum:]') REMOVED from \#${device_name}:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Hostname: ${hostname}
IP Address: ${ip_address}
MAC Address: ${mac_address}
\`\`\`"
    fi
    sleep 1
done < /tmp/wifi_clients.txt

logger -p local0.info -t dhcp-remove-notify "Client removal check completed."
/etc/script/98-dhcp
