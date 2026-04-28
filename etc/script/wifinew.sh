#!/bin/sh

TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"


# Variables
NEIGHBOR_IP="1.1.1.1"      # IP address of the neighbor you want to check
WIFI_INTERFACE="wlan0"         # Replace with your Wi-Fi interface name (e.g., wlan0 or wlan1)
WIFI_SSID="your_wifi_ssid"     # Wi-Fi SSID (Optional, if needed for logging)
TELEGRAM_TOKEN=$TOKEN  # Your Telegram bot token
CHAT_ID=$ID        # Your Telegram chat ID
WIFI_STATUS_FILE="/tmp/wifi_status.txt"  # File to track the Wi-Fi status (enabled/disabled)

# Function to disable Wi-Fi
disable_wifi() {
    echo "Disabling Wi-Fi..."
    wifi down
    # Store status in file
    echo "down" > $WIFI_STATUS_FILE
    # Optional: Send Telegram message about Wi-Fi being disabled
    MESSAGE="Neighbor device is down, disabling Wi-Fi: $WIFI_SSID"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$MESSAGE"
}

# Function to enable Wi-Fi
enable_wifi() {
    echo "Enabling Wi-Fi..."
    wifi up
    # Store status in file
    echo "up" > $WIFI_STATUS_FILE
    # Optional: Send Telegram message about Wi-Fi being enabled
    MESSAGE="Neighbor device is back online, enabling Wi-Fi: $WIFI_SSID"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$MESSAGE"
}

# Check if neighbor is reachable
ping -c 4 $NEIGHBOR_IP > /dev/null 2>&1

# If the neighbor is down and Wi-Fi is not already down, disable Wi-Fi
if [ $? -ne 0 ]; then
    # If Wi-Fi is not already down (check the status file)
    if [ ! -f $WIFI_STATUS_FILE ] || [ "$(cat $WIFI_STATUS_FILE)" != "down" ]; then
        disable_wifi
    fi
else
    # If neighbor is up and Wi-Fi is down, enable Wi-Fi
    if [ -f $WIFI_STATUS_FILE ] && [ "$(cat $WIFI_STATUS_FILE)" == "down" ]; then
        enable_wifi
    fi
fi

