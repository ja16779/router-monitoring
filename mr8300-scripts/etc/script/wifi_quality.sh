#!/bin/sh
# wifi-quality.sh - Wi-Fi quality checker with Signal, Noise, and Link Quality thresholds

# Load config
. /etc/script/wifi-quality.conf

send_telegram() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="${message}" >/dev/null
}

interfaces=$(iwinfo | grep "ESSID" | awk '{print $1}')

echo "=== Wi-Fi Quality Report ==="
for iface in $interfaces; do
    essid=$(iwinfo "$iface" info | grep "ESSID" | cut -d'"' -f2)
    signal=$(iwinfo "$iface" info | grep "Signal" | awk '{print $2}')
    noise=$(iwinfo "$iface" info | grep "Noise" | awk '{print $5}')
    quality_raw=$(iwinfo "$iface" info | grep "Quality" | awk '{print $6}')
    bitrate=$(iwinfo "$iface" info | grep "Bit Rate" | awk '{print $3,$4}')

    # Parse quality into percentage
    quality_num=$(echo "$quality_raw" | awk -F'/' '{print $1}')
    quality_max=$(echo "$quality_raw" | awk -F'/' '{print $2}')
    quality_pct=$((100 * quality_num / quality_max))

    echo "Interface: $iface"
    echo "  ESSID:   $essid"
    echo "  Signal:  $signal dBm"
    echo "  Noise:   $noise dBm"
    echo "  Quality: $quality_pct %"
    echo "  Bitrate: $bitrate"

    # Threshold checks
    #if [ "$signal" -lt "$SIGNAL_THRESHOLD" ]; then
    #    alert="Low signal on $essid ($signal dBm)"
    #    echo "  ALERT: $alert"
    #    logger -t wifi-quality "$alert"
    #    #send_telegram "$alert"
    #fi

    #if [ "$noise" -gt "$NOISE_THRESHOLD" ]; then
    #    alert="High noise on $essid ($noise dBm)"
    #    echo "  ALERT: $alert"
    #    logger -t wifi-quality "$alert"
    #    #send_telegram "$alert"
    #fi

    if [ "$quality_pct" -lt "$QUALITY_THRESHOLD" ]; then
        alert="Low link quality on $essid ($quality_pct %)"
        echo "  ALERT: $alert"
        logger -t wifi-quality "$alert"
        #send_telegram "$alert"
	send_telegram "\#${ESSID}:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
ESSID: ${essid}
Quality:$alert
\`\`\`"

    fi

    echo ""
done
