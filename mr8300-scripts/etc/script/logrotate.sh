#!/bin/sh

LOGFILE="/tmp/dnsmasq.log"
ARCHIVE_DIR="/tmp/mountd/disk1_part1/dnsmasq_logs"  # Optional: change to persistent storage
DATE=$(date +%Y-%m-%d_%H-%M-%S)

mkdir -p "$ARCHIVE_DIR"

if [ -f "$LOGFILE" ]; then
    cp "$LOGFILE" "$ARCHIVE_DIR/dnsmasq_$DATE.log"
    echo "" > "$LOGFILE"
fi

/etc/init.d/dnsmasq restart
logger -t dnsmasq_logrotate "dnsmasq log rotated and service restarted at $DATE"
