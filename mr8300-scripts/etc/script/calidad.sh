#!/bin/bash

 TOKEN="REDACTED_BOT_TOKEN"
 ID="716542586"
 URL="https://api.telegram.org/bot$TOKEN/sendMessage"

#wlan0-0="AXTEL XTREMO_2G"
#wlan0-1="Mega_2.4G_A2DF"
#wlan1-0="AXTEL XTREMO_5G"
#wlan1-1="Mega_5G_A2DF"


# Infinite loop to continuously monitor
while true
do
    # List of interfaces to monitor
    for INTERFACE in wlan0-0 wlan0-1 wlan1-0 wlan1-1
    do
        # Get link quality from iwinfo
        LINK_QUALITY=$(iwinfo $INTERFACE info | grep -i "Link Quality" | awk '{print $6}' | awk -F '/' '{print $1}')
        
        # Calculate percentage
        QUALITY_PERCENTAGE=$(echo "scale=2; ($LINK_QUALITY/70)*100" | bc -l)
        
        # Print the result
        echo "Link Quality: $QUALITY_PERCENTAGE% for $INTERFACE"
        MESSAGE="Link Quality: $QUALITY_PERCENTAGE% for $INTERFACE"
	curl -s -X POST $URL -d chat_id=$ID -d text="$MESSAGE" /dev/null
    done
    
    # Sleep for a certain period (e.g., 5 seconds) before checking again
    sleep 12h
done

