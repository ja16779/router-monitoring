#!/bin/sh

# URL of the firmware page
URL="https://dl.gl-inet.com/router/mt6000/open"

# File to store the last known version
VERSION_FILE="/etc/mt6000_last_version"

# Fetch the page content
html=$(wget -qO- "$URL")

# Extract version strings like 4.8.0-op24
latest_version=$(echo "$html" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+-op[0-9]+' | sort -Vr | head -n 1)

echo $latest_version

# Read the last known version
if [ -f "$VERSION_FILE" ]; then
    last_version=$(cat "$VERSION_FILE")
else
    last_version=""
fi

# Compare and report
if [ "$latest_version" != "$last_version" ]; then
    echo "🔔 New firmware available: $latest_version"
    echo "$latest_version" > "$VERSION_FILE"
else
    echo "✅ Firmware is up to date: $latest_version"
fi
