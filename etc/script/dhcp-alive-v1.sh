#!/bin/sh

LEASES_FILE="/tmp/dhcp.leases"
TEMP_FILE="/tmp/dhcp.leases.tmp"
DELETED_COUNT=0

# Clear temp file
> "$TEMP_FILE"

# Read the leases file line by line
while read -r line; do
    # Extract the IP address from the lease entry
    ip=$(echo "$line" | awk '{print $3}')
    
    # Check if the device responds to ping
    if ping -c 1 -W 1 "$ip" > /dev/null 2>&1; then
        echo "$line" >> "$TEMP_FILE"
    else
        DELETED_COUNT=$((DELETED_COUNT + 1))
    fi
done < "$LEASES_FILE"

# Replace the original leases file with the filtered version
mv "$TEMP_FILE" "$LEASES_FILE"

# Report the number of removed hosts
echo "Deleted $DELETED_COUNT inactive hosts from DHCP leases."

/etc/script/98-dhcp
