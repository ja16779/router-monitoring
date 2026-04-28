#!/bin/sh

# Threshold temperature in Celsius
THRESHOLD=80

# Telegram Bot Token and Chat ID
#TOKEN="REDACTED_BOT_TOKEN"
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# Check the current temperature
TEMP=$(cat /sys/class/thermal/thermal_zone0/hwmon0/subsystem/hwmon2/temp1_input)
TEMP_C=$(($TEMP / 1000))

# Compare with the threshold and send a notification if necessary
if [ "$TEMP_C" -gt "$THRESHOLD" ]; then
    echo "Warning! Temperature in Wifi_5G is above ${THRESHOLD}°C: ${TEMP_C}°C"
    MENSAJE="Warning! Temperature is above ${THRESHOLD}°C: ${TEMP_C}°C on $(uname -n)"
    curl -s -X POST $URL -d chat_id=$ID -d text="$MENSAJE" > /dev/null
fi

