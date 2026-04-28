#/bin/bash
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
# Variables
NEIGHBOR_IP="192.168.8.101"          # IP address of the neighbor you want to check
TELEGRAM_TOKEN=$TOKEN  # Replace with your Telegram bot token
CHAT_ID=$ID        # Replace with your Telegram chat ID

# Check if neighbor is alive
ping -c 4 $NEIGHBOR_IP > /dev/null 2>&1

if [ $? -ne 0 ]; then
     # If the neighbor is not reachable, send a Telegram message
 MESSAGE="Neighbor at $NEIGHBOR_IP is down!"
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \ 
           -d "chat_id=$CHAT_ID" \
           -d "text=$MESSAGE"
 fi
