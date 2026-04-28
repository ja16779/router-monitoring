#!/bin/sh
# Roaming monitor - Detects client roaming between APs via usteer

CACHE="/tmp/usteer_clients.cache"
LEASES="/tmp/dhcp.leases"
LOGTAG="roaming-monitor"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"

send_telegram() {
    curl -skim 10 \
        --data disable_notification="false" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

get_hostname() {
    local mac=$(echo "$1" | tr 'A-F' 'a-f')
    local name=$(grep -i "$mac" "$LEASES" 2>/dev/null | awk '{print $4}' | head -1)
    [ -z "$name" ] || [ "$name" = "*" ] && name="Unknown"
    echo "$name"
}

friendly_ap() {
    local ap="$1"
    case "$ap" in
        192.168.10.2*) node="Beryl" ;;
        *) node="Flint2" ;;
    esac
    case "$ap" in
        *wlan0-1) echo "$node/2.4G-Mega" ;;
        *wlan0)  echo "$node/2.4G-IOT" ;;
        *wlan1-1) echo "$node/5G-Mega" ;;
        *wlan1)  echo "$node/5G-Axtel" ;;
        *) echo "$node/$ap" ;;
    esac
}

# Build current state: MAC|AP|SIGNAL (preserving colons in MAC)
# Sort by strongest signal and keep only one entry per MAC
ubus call usteer get_clients 2>/dev/null | \
    awk '
    /"[0-9a-f][0-9a-f]:/ { gsub(/"/, ""); mac=$1; sub(/:$/, "", mac) }
    /"connected": true/ { connected=1 }
    /"signal":/ && connected { gsub(/[^0-9-]/, ""); print mac "|" ap "|" $0; connected=0 }
    /hostapd\.wlan|#hostapd\.wlan/ { gsub(/"/, ""); ap=$1; sub(/:$/, "", ap) }
    ' | sort -t'|' -k1,1 -k3,3nr | awk -F'|' '!seen[$1]++' > /tmp/usteer_clients.new

# Compare with cache
if [ -f "$CACHE" ]; then
    while IFS='|' read -r mac ap signal; do
        old_ap=$(grep "^${mac}|" "$CACHE" | cut -d'|' -f2)
        if [ -n "$old_ap" ] && [ "$old_ap" != "$ap" ]; then
            hostname=$(get_hostname "$mac")
            from=$(friendly_ap "$old_ap")
            to=$(friendly_ap "$ap")
            timestamp=$(date '+%H:%M:%S')
            mac_upper=$(echo "$mac" | tr 'a-f' 'A-F')

            msg="<b>#Roaming</b> ${timestamp}
<pre>
Client:  ${hostname}
MAC:     ${mac_upper}
Signal:  ${signal} dBm
From:    ${from}
To:      ${to}
</pre>"
            logger -t "$LOGTAG" "$hostname ($mac_upper) roamed from $from to $to (${signal}dBm)"
            send_telegram "$msg"
        fi
    done < /tmp/usteer_clients.new
fi

# Update cache
mv /tmp/usteer_clients.new "$CACHE"
