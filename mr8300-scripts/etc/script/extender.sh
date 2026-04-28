#!/bin/sh

TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"




# List of IPs to monitor
IPs="192.168.8.234 192.168.8.224 192.168.9.129"

# Path to the script to run on failure
FAILURE_SCRIPT="/root/failure_script.sh"

# Ping each IP and check if it's reachable
for IP in $IPs; do
    if ! ping -c 1 -W 1 $IP > /dev/null; then
        echo "IP $IP is unreachable. Running failure script..."
        # Run the failure script
       MENSAJE="IP $IP is unreachable"
       curl -s -X POST $URL -d chat_id=$ID -d text="$MENSAJE"
    fi
done
