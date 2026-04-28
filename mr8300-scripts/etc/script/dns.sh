#!/bin/sh
# dns_health_check.sh

UPSTREAM="127.0.0.1"
PORT="3053"
DOMAIN="example.com"
LOG="/var/log/dns_health.log"
TIMEOUT=2

timestamp=$(date "+%Y-%m-%d %H:%M:%S")

# Run drill
result=$(drill @$UPSTREAM -p $PORT $DOMAIN 2>/dev/null)

echo "$result"

# Extract latency (numeric + unit)
latency=$(echo "$result" | grep "Query time" | awk '{print $4,$5}')
# Example output: "12 msec"

# Extract status safely
status=$(echo "$result" | grep "status:" | awk -F'status: ' '{print $2}' | awk '{print $1}' | tr -d ',')

echo "$latency"
echo "$status"

# Log results
if [ -z "$latency" ]; then
    echo "$timestamp FAIL (no response)" >> "$LOG"
else
    echo "$timestamp $status $latency" >> "$LOG"
fi
