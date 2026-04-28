#!/bin/bash

# URL pattern for the firmware files
BASE_URL="https://fw.gl-inet.com/firmware/mt6000-open/testing/"
PATTERN="openwrt-*.bin"

# Temporary file to store the list of files
TEMP_FILE="firmware_list.txt"

# Fetch the list of matching files from the server
curl -s "${BASE_URL}" | grep -oP "${PATTERN}" > "$TEMP_FILE"

# Check if any files are found
if [[ ! -s "$TEMP_FILE" ]]; then
    echo "No firmware files matching the pattern were found."
    exit 1
fi

# File to store the latest known version for each firmware file
VERSION_FILE="last_firmware_versions.txt"

# Initialize the version file if it doesn't exist
if [[ ! -f "$VERSION_FILE" ]]; then
    touch "$VERSION_FILE"
fi

# Iterate through each firmware file and check its header
while read -r FILE; do
    FULL_URL="${BASE_URL}${FILE}"
    LATEST_VERSION=$(curl -sI "$FULL_URL" | grep -i "Last-Modified" | awk '{print $0}')
    
    # Fetch stored version
    STORED_VERSION=$(grep "$FILE" "$VERSION_FILE" | awk -F':' '{print $2}')

    # Compare and update
    if [[ "$LATEST_VERSION" == "$STORED_VERSION" ]]; then
        echo "$FILE: Firmware is up-to-date!"
    else
        echo "$FILE: Firmware version has been updated!"
        sed -i "/$FILE/d" "$VERSION_FILE" # Remove old entry
        echo "$FILE:$LATEST_VERSION" >> "$VERSION_FILE"
        echo "$FILE: Updated version stored."
    fi
done < "$TEMP_FILE"

# Cleanup
rm -f "$TEMP_FILE"
