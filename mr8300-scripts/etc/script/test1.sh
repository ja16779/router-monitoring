#!/bin/sh

send_to_telegram() {
    logger -p local0.info -t dhcp-remove-notify "$1"
    token="REDACTED_BOT_TOKEN"
    chat_id="716542586"

    if [ -n "$token" ] && [ -n "$chat_id" ]; then
        curl -s --max-time 10 \
            --data disable_notification="false" \
            --data parse_mode="MarkdownV2" \
            --data chat_id="$chat_id" \
            --data-urlencode "text=$1" \
            "https://api.telegram.org/bot${token}/sendMessage" > /dev/null
    else
        logger -p local0.info -t dhcp-remove-notify "Error: Telegram chat_id or token is empty"
    fi
}

# Inicializa lista de clientes si no existe
if [ ! -f /tmp/wifi_clients.txt ]; then
    awk '{print $3,$4,$5}' /tmp/dhcp.leases > /tmp/wifi_clients.txt
fi

device_name=$(sed 's/[^a-zA-Z0-9]//g' /tmp/sysinfo/model)

# Procesa cada cliente
while read -r line; do
    ip_address=$(echo "$line" | awk '{print $1}')
    hostname=$(echo "$line" | awk '{print $2}')
    mac_address=$(echo "$line" | awk '{print $3}')

    ping -c 1 -W 1 "$ip_address" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        # Elimina del archivo de clientes
        sed -i "/${ip_address} ${hostname} ${mac_address}/d" /tmp/wifi_clients.txt

        # Elimina del archivo dhcp.leases si coincide MAC
        sed -i "/${mac_address}/d" /tmp/dhcp.leases

        logger -p local0.info -t dhcp-remove-notify "Device removed: $hostname ($ip_address)"
        send_to_telegram "\#$(echo "$hostname" | sed 's/[^a-zA-Z0-9]//g') REMOVED from \#${device_name}:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Hostname: ${hostname}
IP Address: ${ip_address}
MAC Address: ${mac_address}
\`\`\`"
    fi
    sleep 1
done < /tmp/wifi_clients.txt
