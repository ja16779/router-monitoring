#!/bin/bash

send_to_telegram() {
    logger -p local0.info -t clients_connected "$1"
    #token="REDACTED_BOT_TOKEN"
    token="REDACTED_BOT_TOKEN"
    chat_id="716542586"
    if [[ -n "${token}" ]] && [[ -n "${chat_id}" ]]; then
        curl -skim 10 --data disable_notification="false" --data parse_mode="MarkdownV2" --data chat_id="$chat_id" --data-urlencode "text=$1" "https://api.telegram.org/bot${token}/sendMessage" > /dev/null
    else
        logger -p local0.info -t connected-users "Error: Your telegram chat_id or token is empty"
    fi
}

TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"



# File paths
arp_file="/tmp/arp_data.txt"
log_file="/tmp/usuarios-${HOSTNAME}-$(date +%F).log"
timestamp_log="/tmp/usuariosfecha-${HOSTNAME}-$(date +%F).log"
connected_log="/tmp/usuariosconectados-${HOSTNAME}-$(date +%F).log"
charur_file="/tmp/charur.txt"
alive_count_log="/tmp/alive_count-${HOSTNAME}-$(date +%F).log"

# Clear files if they exist
> "$arp_file"
> "$log_file"
> "$timestamp_log"
> "$connected_log"
> "$charur_file"
> "$alive_count_log"
>  /tmp/prueba.txt

# Step 1: Extract IP and MAC addresses from ARP table (skip header)
cat /proc/net/arp | awk 'NR>1 {print $1 " " $4}' > "$arp_file"

# Step 2: Log corresponding DHCP leases for IPs in ARP table
for ip in $(awk 'NR>1 {print $1}' /proc/net/arp); do
    grep -w "$ip" /tmp/dhcp.leases >> "$log_file"
done

# Step 3: Add the timestamp for each lease
for t in $(awk '{print $1}' /tmp/dhcp.leases); do
  date -d @$t >> "$timestamp_log"
done

# Step 4: Combine DHCP leases and timestamps into a single log file
paste /tmp/dhcp.leases "$timestamp_log" > "$connected_log"

# Step 5: Match IPs from ARP table with the combined log, and save the result in charur.txt
for a in $(awk '{print $1}' "$arp_file"); do
   grep "$a" "$connected_log" >> "$charur_file"
done

# Initialize user count
alive_user_count=0

# Debugging: Output content of charur.txt
#echo "Contents of charur.txt:"
#cat "$charur_file"
#echo "-------------------------------------------"

# Step 6: Ping each host listed in charur.txt and check if it's alive
cat "$charur_file" | awk '{print $3}' | while read ip; do
    # Trim any leading or trailing whitespace from IP
    ip=$(echo "$ip" | xargs)

    # Debugging: Check the IP being processed
#    echo "Pinging IP: '$ip'"

    # Ping the host with a timeout of 3 seconds and count 1 ping
    if ping -c 1 -W 3 "$ip" &> /dev/null; then
        # If the host is reachable, count it as alive
        alive_user_count=$((alive_user_count + 1))

        # Debugging: Show incrementing count immediately after increment
 #       echo "Alive user count incremented: $alive_user_count"
        # Optionally, print details of the alive host
        awk -v ip="$ip" '$3 == ip {print $2, $3, $4, $5}' "$charur_file" >> /tmp/prueba.txt
    else
        # If the host is not reachable, print debugging info
        echo -e "IP $ip is NOT reachable." > /dev/null
    fi
done

# Explicitly output the alive user count after the loop to avoid overwriting
#echo "Debugging: Alive client count after loop: $usuarios"

# Step 7: Log the count of alive clients
#echo "Number of alive clients: $alive_user_count" > "$alive_count_log"

# Step 8: Output the result to the terminal or to a specific log
usuarios=$(cat /tmp/prueba.txt | awk '{print $1,$2,$3}')
connected=$(cat /tmp/prueba.txt | wc -l)
rm /tmp/prueba.txt
send_to_telegram "\#$(echo "${HOSTNAME}" | sed 's/[^a-zA-Z0-9]//g') USUARIOS CONECTADOS \# $connected:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Usuarios Conectados: $connected
$usuarios
\`\`\`"
rm /tmp/prueba.txt
