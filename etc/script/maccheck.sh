#!/bin/sh

# Define your Telegram bot API token and chat ID
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# Define a list of labels and MAC addresses
mac_list="b0:19:21:69:5d:8d RE_5G
b0:19:21:69:5d:8c RE_2G
9a:48:27:0e:54:47 Cochera"

# Initialize message variable for summary
#message="WiFi Clients Status:"

# Get wireless client information using 'iw dev'
#wifi_clients=$(arp -a | wc -l )


#curl -s -X POST $URL -d chat_id=$ID -d text="Usuarios Conectados $wifi_clients"

# Get wired client information using '/proc/net/arp'
arp_clients=$(cat /proc/net/arp)

# Debugging: Print the wireless and ARP client information
echo "Wi-Fi clients:\n$wifi_clients\n"
echo -e "ARP clients:$arp_clients"

# Use a while loop to process the mac_list
echo "$mac_list" | while read -r mac label; do
    # Check if the MAC address is present in the Wi-Fi client list or ARP table
    #wifi_count=$(echo "$wifi_clients" | grep -i "$mac" | wc -l)
    arp_count=$(echo "$arp_clients" | grep -i "$mac" | wc -l)

    echo -e $arp_count 
     

#    # If found in either Wi-Fi or ARP, count as connected
    total_count=$arp_count


    if [ "$total_count" -gt 0 ]; then
        message="$message $label $mac has $total_count clients connected."
#	curl -s -X POST $URL -d chat_id=$ID -d text="$message"
    else
        message="$message $label $mac has $total_count clients connected."
 #      curl -s -X POST $URL -d chat_id=$ID -d text="$message"
    fi


done

# Send the final message to the Telegram bot


#curl -s -X POST $URL -d chat_id=$ID -d text="$message"

# Output the message to the console


