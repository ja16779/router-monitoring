#!/bin/sh
# OpenWrt Custom Prometheus Exporter
# Exposes SQM/CAKE, WiFi clients, and network metrics
# Run with: /usr/bin/openwrt_exporter.sh
# Listens on port 9101

PORT=9101

serve_metrics() {
    # System metrics
    UPTIME=$(awk '{print $1}' /proc/uptime)
    LOAD=$(awk '{print $1}' /proc/loadavg)
    MEM_TOTAL=$(awk '/MemTotal/ {print $2*1024}' /proc/meminfo)
    MEM_FREE=$(awk '/MemAvailable/ {print $2*1024}' /proc/meminfo)
    MEM_USED=$((MEM_TOTAL - MEM_FREE))
    TEMP=$(awk '{printf "%.1f", $1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    CONNS=$(wc -l < /proc/net/nf_conntrack 2>/dev/null || echo "0")

    # Start metrics output
    cat << METRICS
# HELP openwrt_uptime_seconds System uptime in seconds
# TYPE openwrt_uptime_seconds gauge
openwrt_uptime_seconds $UPTIME

# HELP openwrt_load1 1 minute load average
# TYPE openwrt_load1 gauge
openwrt_load1 $LOAD

# HELP openwrt_memory_bytes Memory usage in bytes
# TYPE openwrt_memory_bytes gauge
openwrt_memory_bytes{type="total"} $MEM_TOTAL
openwrt_memory_bytes{type="used"} $MEM_USED
openwrt_memory_bytes{type="free"} $MEM_FREE

# HELP openwrt_temperature_celsius CPU temperature
# TYPE openwrt_temperature_celsius gauge
openwrt_temperature_celsius $TEMP

# HELP openwrt_connections_total Active connections
# TYPE openwrt_connections_total gauge
openwrt_connections_total $CONNS

METRICS

    # Network interface metrics
    echo "# HELP openwrt_network_bytes_total Network traffic bytes"
    echo "# TYPE openwrt_network_bytes_total counter"
    for iface in eth1 lan5 br-lan br-lan.8 br-lan.10; do
        if [ -d "/sys/class/net/$iface" ]; then
            RX=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
            TX=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
            echo "openwrt_network_bytes_total{interface=\"$iface\",direction=\"rx\"} $RX"
            echo "openwrt_network_bytes_total{interface=\"$iface\",direction=\"tx\"} $TX"
        fi
    done

    # WiFi clients
    echo ""
    echo "# HELP openwrt_wifi_clients Number of connected WiFi clients"
    echo "# TYPE openwrt_wifi_clients gauge"
    for iface in wlan0 wlan0-1 wlan1 wlan1-1; do
        COUNT=$(iwinfo $iface assoclist 2>/dev/null | grep -c "dBm" || echo 0)
        BAND="2.4GHz"
        echo "$iface" | grep -q "wlan1" && BAND="5GHz"
        echo "openwrt_wifi_clients{interface=\"$iface\",band=\"$BAND\"} $COUNT"
    done 2>/dev/null

    # WiFi client signal strength
    echo ""
    echo "# HELP openwrt_wifi_signal_dbm WiFi client signal strength"
    echo "# TYPE openwrt_wifi_signal_dbm gauge"
    for iface in wlan0 wlan0-1 wlan1 wlan1-1; do
        BAND="2.4GHz"
        echo "$iface" | grep -q "wlan1" && BAND="5GHz"
        iwinfo $iface assoclist 2>/dev/null | grep "dBm" | while read MAC SIGNAL REST; do
            DBM=$(echo "$SIGNAL" | grep -oE '[-0-9]+' | head -1)
            echo "openwrt_wifi_signal_dbm{interface=\"$iface\",band=\"$BAND\",mac=\"$MAC\"} $DBM"
        done
    done 2>/dev/null

    # SQM/CAKE metrics
    echo ""
    echo "# HELP openwrt_cake_bandwidth_bps CAKE configured bandwidth"
    echo "# TYPE openwrt_cake_bandwidth_bps gauge"
    echo "# HELP openwrt_cake_drops_total CAKE dropped packets"
    echo "# TYPE openwrt_cake_drops_total counter"
    echo "# HELP openwrt_cake_bytes_total CAKE bytes per tin"
    echo "# TYPE openwrt_cake_bytes_total counter"
    echo "# HELP openwrt_cake_delay_us CAKE average delay per tin"
    echo "# TYPE openwrt_cake_delay_us gauge"

    for wan in eth1 lan5; do
        [ ! -d "/sys/class/net/$wan" ] && continue
        WAN_LABEL="wan1"
        [ "$wan" = "lan5" ] && WAN_LABEL="wan2"

        # Download (interface directly)
        QDISC_INFO=$(tc -s qdisc show dev "$wan" 2>/dev/null | grep -A5 "qdisc cake")
        if [ -n "$QDISC_INFO" ]; then
            RATE=$(echo "$QDISC_INFO" | grep -oE 'bandwidth [0-9]+[KMG]?bit' | awk '{gsub("Kbit","000"); gsub("Mbit","000000"); gsub("Gbit","000000000"); gsub("bit",""); print $2}')
            DROPS=$(echo "$QDISC_INFO" | grep -oE 'dropped [0-9]+' | awk '{print $2}')
            [ -z "$RATE" ] && RATE=0
            [ -z "$DROPS" ] && DROPS=0
            echo "openwrt_cake_bandwidth_bps{wan=\"$WAN_LABEL\",direction=\"download\"} $RATE"
            echo "openwrt_cake_drops_total{wan=\"$WAN_LABEL\",direction=\"download\"} $DROPS"

            # Per-tin stats for download
            TIN_NUM=0
            for TIN in Bulk BE Video Voice; do
                TIN_NUM=$((TIN_NUM + 1))
                TIN_STATS=$(tc -s class show dev "$wan" 2>/dev/null | grep -A10 "class cake.*:$TIN_NUM ")
                BYTES=$(echo "$TIN_STATS" | grep -oE 'Sent [0-9]+ bytes' | awk '{print $2}')
                DELAY=$(echo "$TIN_STATS" | grep -oE 'av_delay [0-9.]+us' | awk '{gsub("us",""); print $2}')
                [ -z "$BYTES" ] && BYTES=0
                [ -z "$DELAY" ] && DELAY=0
                echo "openwrt_cake_bytes_total{wan=\"$WAN_LABEL\",direction=\"download\",tin=\"$TIN\"} $BYTES"
                echo "openwrt_cake_delay_us{wan=\"$WAN_LABEL\",direction=\"download\",tin=\"$TIN\"} $DELAY"
            done
        fi

        # Upload (ifb interface)
        IFB="ifb4$wan"
        QDISC_INFO=$(tc -s qdisc show dev "$IFB" 2>/dev/null | grep -A5 "qdisc cake")
        if [ -n "$QDISC_INFO" ]; then
            RATE=$(echo "$QDISC_INFO" | grep -oE 'bandwidth [0-9]+[KMG]?bit' | awk '{gsub("Kbit","000"); gsub("Mbit","000000"); gsub("Gbit","000000000"); gsub("bit",""); print $2}')
            DROPS=$(echo "$QDISC_INFO" | grep -oE 'dropped [0-9]+' | awk '{print $2}')
            [ -z "$RATE" ] && RATE=0
            [ -z "$DROPS" ] && DROPS=0
            echo "openwrt_cake_bandwidth_bps{wan=\"$WAN_LABEL\",direction=\"upload\"} $RATE"
            echo "openwrt_cake_drops_total{wan=\"$WAN_LABEL\",direction=\"upload\"} $DROPS"

            # Per-tin stats for upload
            TIN_NUM=0
            for TIN in Bulk BE Video Voice; do
                TIN_NUM=$((TIN_NUM + 1))
                TIN_STATS=$(tc -s class show dev "$IFB" 2>/dev/null | grep -A10 "class cake.*:$TIN_NUM ")
                BYTES=$(echo "$TIN_STATS" | grep -oE 'Sent [0-9]+ bytes' | awk '{print $2}')
                DELAY=$(echo "$TIN_STATS" | grep -oE 'av_delay [0-9.]+us' | awk '{gsub("us",""); print $2}')
                [ -z "$BYTES" ] && BYTES=0
                [ -z "$DELAY" ] && DELAY=0
                echo "openwrt_cake_bytes_total{wan=\"$WAN_LABEL\",direction=\"upload\",tin=\"$TIN\"} $BYTES"
                echo "openwrt_cake_delay_us{wan=\"$WAN_LABEL\",direction=\"upload\",tin=\"$TIN\"} $DELAY"
            done
        fi
    done

    # DHCP leases count
    echo ""
    echo "# HELP openwrt_dhcp_leases DHCP active leases"
    echo "# TYPE openwrt_dhcp_leases gauge"
    LEASES_IOT=$(grep -c "192.168.8." /tmp/dhcp.leases 2>/dev/null || echo 0)
    LEASES_LAN=$(grep -c "192.168.10." /tmp/dhcp.leases 2>/dev/null || echo 0)
    echo "openwrt_dhcp_leases{network=\"iot\"} $LEASES_IOT"
    echo "openwrt_dhcp_leases{network=\"lan\"} $LEASES_LAN"
}

# Simple HTTP server using netcat
while true; do
    METRICS=$(serve_metrics)
    RESPONSE="HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: ${#METRICS}\r\nConnection: close\r\n\r\n$METRICS"
    echo -e "$RESPONSE" | nc -l -p $PORT -w 1 2>/dev/null
done
