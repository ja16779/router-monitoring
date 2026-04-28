#!/bin/bash

# Telegram Bot Token and Chat ID
#TOKEN="REDACTED_BOT_TOKEN"
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# Check the current temperature
MESSAGE=$(iwinfo | grep Tx-Power)

# Compare with the threshold and send a notification if necessary

# Threshold for the number of processes
THRESHOLD=200

# Infinite loop to continuously check processes
while true
do
    # Get the number of running processes
    PROCESS_COUNT=$(ps | wc -l)
    
    # Log the result
    if [ "$PROCESS_COUNT" -gt "$THRESHOLD" ]; then
        echo "$(date): WARNING! Number of running processes ($PROCESS_COUNT) exceeds the threshold ($THRESHOLD)!" >> /var/log/process_check.log
    	MESSAGE="$(date): WARNING! Number of running processes ($PROCESS_COUNT) exceeds the threshold ($THRESHOLD)!"
        curl -s -X POST $URL -d chat_id=$ID -d text="$MESSAGE" > /dev/null
	else
        echo "$(date): Number of running processes: $PROCESS_COUNT" >> /var/log/process_check.log
    fi
    
    # Sleep for a certain period (e.g., 60 seconds) before checking again
    sleep 1h
done
