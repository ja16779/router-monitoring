#!/bin/sh

# Use BusyBox ps output (PID USER STAT COMMAND)
pids=$(ps | grep "[d]bclient -lroot 192.168.10.2 scp -t /tmp/dhcp.leases" | awk '{print $1}')

count=$(echo "$pids" | wc -w)

if [ "$count" -ge 2 ]; then
    echo "Found $count matching processes. Killing them..."
    for pid in $pids; do
        kill -9 "$pid"
    done
else
    echo "Only $count matching process found. No action taken."
fi
