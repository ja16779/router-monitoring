#!/bin/sh
###############################################
# Script to clean up offline hosts from dhcp.leases
# Created: Apr / 2025
###############################################

### Initialization
LEASE_FILE="/tmp/dhcp.leases"  # Path to the DHCP leases file
ARP_TABLE="/proc/net/arp"     # ARP table to check active hosts
temp_file="/tmp/dhcp.leases.tmp"  # Temporary file for cleaned leases

### Function to check if a host is online
is_host_online() {
    local mac="$1"
    grep -q "$mac" "$ARP_TABLE"  # Search for the MAC address in the ARP table
}

### Function to clean up the DHCP leases file
cleanup_leases() {
    if [ ! -f "$LEASE_FILE" ]; then
        echo "DHCP leases file not found at $LEASE_FILE."
        exit 1
    fi

    local temp_file="/tmp/dhcp.leases.tmp"  # Temporary file for cleaned leases
    >"$temp_file"                          # Create/clear the temporary file

    while read -r line; do
        local mac=$(echo "$line" | awk '{print $2}')  # Extract MAC address from the lease line
        if is_host_online "$mac"; then
            echo "$line" >>"$temp_file"  # Keep online hosts
        else
            echo "Removing offline host: $mac"
        fi
    done <"$LEASE_FILE"

     # Count total clients and append to the file
    local total_clients=$(wc -l <"$temp_file")
    echo "Total clients: $total_clients" >>"$temp_file"



    mv "$temp_file" "$LEASE_FILE"  # Replace the original file with the cleaned-up file
    echo "Cleanup completed."
}

### Main Execution
cleanup_leases
/etc/script/98-dhcp
