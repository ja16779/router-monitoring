#!/bin/bash

total_clients=0

# List all Wi-Fi interfaces
wifi_interfaces=$(iw dev | grep Interface | awk '{print $2}')

# Iterate over each Wi-Fi interface
for iface in $wifi_interfaces; do
    echo "Clients connected to $iface:"

    # Use iw to list associated stations (clients)
    clients=$(iw dev $iface station dump | grep "Station" | awk '{print $2}')

    # Check if there are clients and count them
    if [[ -n "$clients" ]]; then
        num_clients=$(echo "$clients" | wc -l)
        total_clients=$((total_clients + num_clients))
        echo "$clients"
        echo "Number of clients on $iface: $num_clients"
    else
        echo "No clients connected."
    fi
    echo
done

# Print the total number of clients
echo "Total number of clients connected to all Wi-Fi interfaces: $total_clients"
