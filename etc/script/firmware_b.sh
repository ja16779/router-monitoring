#!/bin/bash

# Base URL for the firmware
BASE_URL="https://fw.gl-inet.com/firmware/mt6000-open/testing/"
EXPECTED_PATTERN="openwrt-mt6000-4.*\.bin" # Simplified pattern for BusyBox compatibility

# Temporary file to store firmware file list
TEMP_FILE="firmware_list.txt"

# Fetch list of files and filter using BusyBox-compatible `grep`
curl -s "${BASE_URL}" | grep -o "openwrt-mt6000-4.*\.bin" > "$TEMP_FILE"

# Check if any firmware files were found
if [[ ! -s "$TEMP_FILE" ]]; then
    echo "No firmware files found matching the pattern!"
    rm -f "$TEMP_FILE"
    exit 1
fi

# File to store version information
VERSION_FILE="firmware_versions_status.txt"

# Clear or initialize the version file
echo "" > "$VERSION_FILE"

# Process each firmware file
while read -r FILE; do
    FULL_URL="${BASE_URL}${FILE}"
    LATEST_VERSION=$(curl -sI "$FULL_URL" | grep -i "Last-Modified" | awk '{print substr($0, index($0, $2))}')

    # Validate the file's name and log information
    if echo "$FILE" | grep -q "openwrt-mt6000-4\..*\..*-op24-.*-.*\.bin"; then
        echo "$FILE matches the expected version pattern." >> "$VERSION_FILE"
        echo "$FILE Last-Modified: $LATEST_VERSION" >> "$VERSION_FILE"
        echo "--------------------------------------" >> "$VERSION_FILE"
    else
        echo "$FILE does NOT match the expected version pattern!" >> "$VERSION_FILE"
        echo "--------------------------------------" >> "$VERSION_FILE"
    fi
done < "$TEMP_FILE"

# Cleanup
rm -f "$TEMP_FILE"

# Display the results
cat "$VERSION_FILE"
