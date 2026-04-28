#!/bin/bash

# URL of the firmware file
FIRMWARE_URL="https://fw.gl-inet.com/firmware/mt6000-open/testing/openwrt-mt6000-4.7.5-op24-0418-1744958106.bin"

# File to store the last known version
VERSION_FILE="last_firmware_version.txt"

# Function to fetch the latest version
get_latest_version() {
    curl -sI "$FIRMWARE_URL" | grep -i "Last-Modified" | awk '{print $0}'
}

# Fetch the latest version details
LATEST_VERSION=$(get_latest_version)

# If no version file exists, create one
if [[ ! -f $VERSION_FILE ]]; then
    echo "No version record found. Storing the latest version..."
    echo "$LATEST_VERSION" > "$VERSION_FILE"
    echo "Version recorded: $LATEST_VERSION"
    exit 0
fi

# Fetch the stored version
STORED_VERSION=$(cat "$VERSION_FILE")

# Compare the versions
if [[ "$LATEST_VERSION" == "$STORED_VERSION" ]]; then
    echo "Firmware is already up-to-date!"
else
    echo "Firmware version has been updated!"
    echo "$LATEST_VERSION" > "$VERSION_FILE"
    echo "Updated version stored: $LATEST_VERSION"
fi
