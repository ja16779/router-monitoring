#!/bin/sh

LEASES_FILE="/tmp/dhcp.leases"

send_to_telegram() {
    logger -p local0.info -t dhcp-remove-notify "$1"
    token="REDACTED_BOT_TOKEN"
    chat_id="716542586"

    if [ -n "$token" ] && [ -n "$chat_id" ]; then
        curl -s --max-time 10 \
            --data-urlencode "text=$1" \
            --data "disable_notification=false" \
            --data "parse_mode=MarkdownV2" \
            --data "chat_id=$chat_id" \
            "https://api.telegram.org/bot${token}/sendMessage" > /dev/null
    else
        logger -p local0.info -t wifi_connection "Error: Telegram chat_id or token is empty"
    fi
}

# Map interface to ESSID
case "$1" in
    wlan0)    ESSID="IOT" ;;
    wlan0-1)  ESSID="Mega_2.4G_A2DF" ;;
    wlan1)    ESSID="AXTEL XTREMO" ;;
    wlan1-1)  ESSID="Mega_5G_A2DF" ;;
    #phy1-ap0) ESSID="IOT5G" ;;
    phy0-ap0) ESSID="AXTEL XTREMO 2G" ;;
    *) echo "Unknown interface: $1"; exit 1 ;;
esac

MAC="$3"
EVENT="$2"

# Extract IP and hostname
ipaddress=$(awk -v mac="$MAC" 'tolower($1)==tolower(mac) {print $3}' "$LEASES_FILE")
hostname=$(awk -v mac="$MAC" 'tolower($1)==tolower(mac) {print $4}' "$LEASES_FILE")
[ "$hostname" = "*" ] && hostname="NONAME"
safe_hostname=$(echo "$hostname" | sed 's/[^a-zA-Z0-9]//g')

# Extract iwinfo metrics
iwinfo_output=$(iwinfo "$1" info)
#bitrate=$(echo "$iwinfo_output" | awk -F':' '/Bit Rate/ {gsub(/^[ \t]+/, "", $2); print $2}')
#signal=$(echo "$iwinfo_output" | awk -F':' '/Signal/ {gsub(/^[ \t]+/, "", $2); print $2}')
#noise=$(echo "$iwinfo_output" | awk -F':' '/Noise/ {gsub(/^[ \t]+/, "", $2); print $2}')
#quality=$(echo "$iwinfo_output" | awk -F':' '/Link Quality/ {gsub(/^[ \t]+/, "", $2); print $2}')
#txpower=$(echo "$iwinfo_output" | awk -F':' '/Tx-Power/ {gsub(/^[ \t]+/, "", $2); print $2}')

    signal=$(iwinfo "$1" info | grep "Signal" | awk '{print $2}')
    noise=$(iwinfo "$1" info | grep "Noise" | awk '{print $5}')
    quality=$(iwinfo "$1" info | grep "Quality" | awk '{print $6}')
    bitrate=$(iwinfo "$1" info | grep "Bit Rate" | awk '{print $3,$4}')
    txpower=$(iwinfo "$1" info | awk -F'Tx-Power:' '/Tx-Power/ {split($2,a,"Link Quality"); gsub(/^[ \t]+/, "", a[1]); print a[1]}')
    # Parse quality into percentage
    quality_num=$(echo "$quality" | awk -F'/' '{print $1}')
    quality_max=$(echo "$quality" | awk -F'/' '{print $2}')
    quality_pct=$((100 * quality_num / quality_max))
    q_pct="${quality_pct}%"



case "$EVENT" in
    AP-STA-CONNECTED)
        send_to_telegram "\#${safe_hostname} connected on \#${ESSID}:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Hostname: ${hostname}
IP Address: ${ipaddress}
MAC Address: ${MAC}
ESSID: ${ESSID}
Bit Rate: ${bitrate}
Signal: ${signal}
Noise: ${noise}
Link Quality: ${q_pct}
Tx-Power: ${txpower}
\`\`\`"
        ;;

    AP-STA-DISCONNECTED)
        send_to_telegram "\#${safe_hostname} disconnected from \#${ESSID}:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Hostname: ${hostname}
IP Address: ${ipaddress}
MAC Address: ${MAC}
ESSID: ${ESSID}
\`\`\`"
        ;;

    *)
        echo "Unknown event: $EVENT"
        exit 1
        ;;
esac
