#!/bin/sh

TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"

mac_list="b0:19:21:69:5d:8d RE_5G
b0:19:21:69:5d:8c RE_2G
9a:48:27:0e:54:47 Cochera"

# Extract MAC addresses from ARP table
arp_clients=$(awk '{print $4}' /proc/net/arp)

message="Connected Clients:\n"

echo "$mac_list" | while read -r mac label; do
    arp_count=$(echo "$arp_clients" | grep -i "$mac" | wc -l)

    message="$message$label ($mac) has $arp_count clients connected.\n"
done

# Send one final Telegram message
curl -s -X POST "$URL" -d "chat_id=$ID" -d "text=$message"
