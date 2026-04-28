#!/bin/bash

# Source token and ID from a secured configuration file
#source /path/to/config.sh

#URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# Infinite loop to continuously monitor
while true
do
    # List of interfaces and their friendly names
    INTERFACES=("wlan0:AXTEL XTREMO_2G" "wlan0-1:Mega_2.4G_A2DF" "wlan1:Interface 1-0" "wlan1-1:Interface 1-1")

    for ITEM in "${INTERFACES[@]}"
    do
        INTERFACE=$(echo $ITEM | cut -d':' -f1)
        FRIENDLY_NAME=$(echo $ITEM | cut -d':' -f2)

        # Get link quality using iwinfo specific to OpenWrt
        LINK_QUALITY=$(iwinfo $INTERFACE info | grep -i "Link Quality" | awk '{print $3}' | awk -F '/' '{print $1}')

        # Check if LINK_QUALITY is a valid number
        if [[ $LINK_QUALITY =~ ^[0-9]+$ ]]; then
            # Calculate percentage
            QUALITY_PERCENTAGE=$(echo "scale=2; ($LINK_QUALITY/70)*100" | bc -l)

            # Print the result
            echo "Link Quality: $QUALITY_PERCENTAGE% for $FRIENDLY_NAME ($INTERFACE)"
            MESSAGE="Link Quality: $QUALITY_PERCENTAGE% for $FRIENDLY_NAME ($INTERFACE)"
            curl -s -X POST $URL -d chat_id=$ID -d text="$MESSAGE" > /dev/null
        else
            echo "Failed to retrieve link quality for $FRIENDLY_NAME ($INTERFACE)"
        fi
    done

    # Sleep for a certain period (e.g., 12 hours) before checking again
    sleep 12h
done

