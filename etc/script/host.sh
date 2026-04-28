#!/bin/sh

# Define input file
lease_file="/tmp/dhcp.leases"
temp_file="/tmp/dhcp_temp.leases"

# Check if lease file exists
if [ ! -f "$lease_file" ]; then
    echo "Error: $lease_file does not exist."
    exit 1
fi

# Create a temporary file to store online hosts
> "$temp_file"

# Read the lease file line by line
while read -r line; do
    # Extract IP address from the DHCP lease line
    ip_address=$(echo "$line" | awk '{print $3}')

    # Check if the host is online
    ping -c 1 -W 1 "$ip_address" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        # If online, write the line to the temp file
        echo "$line" >> "$temp_file"
    else
        # Log or inform about offline hosts
        logger -p local0.info "Host $ip_address is offline and has been removed."
    fi
done < "$lease_file"

# Replace the original file with the filtered file
mv "$temp_file" "$lease_file"

echo "Offline hosts have been removed from $lease_file."
