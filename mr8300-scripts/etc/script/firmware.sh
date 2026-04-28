#!/bin/sh

TOKEN="REDACTED_BOT_TOKEN"
 ID="716542586"
 URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# URL of the XML file
URL="http://download.gl-inet.com.s3.amazonaws.com/"

# Output file to store the search results
SEARCH_FILE="/tmp/firmware_metadata_search.txt"

# Pattern to search for firmware metadata
#FIRMWARE_PATTERN="firmware/mt3000-open/testing/metadata_4\.[0-9]+\.[0-9]+-op24"
FIRMWARE_PATTERN="firmware/mt3000-open/testing/metadata_4.7.0-op24"

# Previous versions file
PREVIOUS_FILE="/tmp/previous_firmware_versions.txt"

# Fetch the XML file and search for the specific pattern
wget -q -O - $URL | grep -E "<Key>$FIRMWARE_PATTERN</Key>" > $SEARCH_FILE

# Check if the specific firmware metadata is in the search results
if [ -s $SEARCH_FILE ]; then
    echo "Firmware metadata matching pattern found in $SEARCH_FILE"
else
    echo "Firmware metadata matching pattern not found in $SEARCH_FILE"
fi

# Check if there is a previous version file
if [ -f $PREVIOUS_FILE ]; then
    # Compare the previous and current listings to check for new versions
    NEW_VERSIONS=$(diff $PREVIOUS_FILE $SEARCH_FILE | grep '>' | sed 's/> //')
    if [ -n "$NEW_VERSIONS" ]; then
        echo "New firmware versions available:"
        echo "$NEW_VERSIONS"
        MESSAGE="New GLINET Version:$NEW_VERSIONS"
        curl -s -X POST $URL -d chat_id=$ID -d text="$MESSAGE" > /dev/null 
    else
        echo "No new firmware versions found."
    fi
else
    echo "No previous versions file found. Saving current versions as the baseline."
fi

# Update the previous versions file with the current listings
cp $SEARCH_FILE $PREVIOUS_FILE

