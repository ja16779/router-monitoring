#!/bin/bash

# Replace with your actual router model and current version
MODEL="gl-MT6000"
CURRENT_VERSION=$(cat /etc/glversion | grep -oP '(?<=version=).*')

# GL.iNet firmware API endpoint
API_URL="https://fw.gl-inet.com/api/v1/version/${MODEL}/release"

# Fetch latest firmware info
LATEST_VERSION=$(curl -s "$API_URL" | grep -oP '(?<="version":")[^"]+')

echo "🔍 Current firmware: $CURRENT_VERSION"
echo "🌐 Latest firmware: $LATEST_VERSION"

if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
    echo "⚠️ Firmware update available!"
    # Optional: trigger download or alert
else
    echo "✅ Firmware is up to date."
fi
