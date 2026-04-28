#!/bin/sh
# Custom Prometheus exporter for GL-MT6000 Grafana dashboard
# Generates router_* metrics with host="glmt6000"

HOST="glmt6000"
METRICS=""

metric() {
    METRICS="${METRICS}${1}\n"
}

# === SYSTEM ===
# Uptime
UPTIME=$(awk '{print int($1)}' /proc/uptime)
metric "# HELP router_system_uptime System uptime in seconds"
metric "# TYPE router_system_uptime gauge"
metric "router_system_uptime{host=\"${HOST}\"} ${UPTIME}"

# Memory percentage
MEMINFO=$(cat /proc/meminfo)
TOTAL=$(echo "$MEMINFO" | awk '/MemTotal/{print $2}')
AVAIL=$(echo "$MEMINFO" | awk '/MemAvailable/{print $2}')
[ -z "$AVAIL" ] && {
    FREE=$(echo "$MEMINFO" | awk '/MemFree/{print $2}')
    BUF=$(echo "$MEMINFO" | awk '/Buffers/{print $2}')
    CACHE=$(echo "$MEMINFO" | awk '/^Cached:/{print $2}')
    AVAIL=$((FREE + BUF + CACHE))
}
MEM_PCT=$((100 * (TOTAL - AVAIL) / TOTAL))
metric "# HELP router_system_mem_pct Memory usage percentage"
metric "# TYPE router_system_mem_pct gauge"
metric "router_system_mem_pct{host=\"${HOST}\"} ${MEM_PCT}"

# Temperature
TEMP=$(awk '{printf "%.1f", $1/1000}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
metric "# HELP router_system_temp CPU temperature in Celsius"
metric "# TYPE router_system_temp gauge"
metric "router_system_temp{host=\"${HOST}\"} ${TEMP}"

# Load
LOAD=$(awk '{print $1}' /proc/loadavg)
metric "# HELP router_system_load System load average 1m"
metric "# TYPE router_system_load gauge"
metric "router_system_load{host=\"${HOST}\"} ${LOAD}"

# Connections (conntrack)
CONNS=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo "0")
metric "# HELP router_system_connections Active connections"
metric "# TYPE router_system_connections gauge"
metric "router_system_connections{host=\"${HOST}\"} ${CONNS}"

metric "# HELP router_conntrack_current Current conntrack entries"
metric "# TYPE router_conntrack_current gauge"
metric "router_conntrack_current{host=\"${HOST}\"} ${CONNS}"

# === CPU ===
CPU1=$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
IDLE1=$(awk '/^cpu /{print $5}' /proc/stat)
sleep 1
CPU2=$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
IDLE2=$(awk '/^cpu /{print $5}' /proc/stat)
CPU_DIFF=$((CPU2 - CPU1))
IDLE_DIFF=$((IDLE2 - IDLE1))
[ "$CPU_DIFF" -gt 0 ] && CPU_PCT=$((100 * (CPU_DIFF - IDLE_DIFF) / CPU_DIFF)) || CPU_PCT=0
metric "# HELP router_cpu_usage CPU usage percentage"
metric "# TYPE router_cpu_usage gauge"
metric "router_cpu_usage{host=\"${HOST}\"} ${CPU_PCT}"

# === WAN PING/LOSS ===
for IFACE_NAME in wan wan2; do
    # Determine IP to ping based on interface
    if [ "$IFACE_NAME" = "wan" ]; then
        GW=$(ip route show default dev eth1 2>/dev/null | awk '/default/{print $3}' | head -1)
        PING_TARGET="${GW:-8.8.8.8}"
    else
        GW=$(ip route show default dev lan5 2>/dev/null | awk '/default/{print $3}' | head -1)
        PING_TARGET="${GW:-1.1.1.1}"
    fi

    PING_RESULT=$(ping -c 3 -W 2 "$PING_TARGET" 2>/dev/null)
    if [ $? -eq 0 ]; then
        PING_MS=$(echo "$PING_RESULT" | grep "round-trip" | cut -d= -f2 | cut -d/ -f2)
        LOSS=$(echo "$PING_RESULT" | grep "loss" | sed 's/.* \([0-9]*\)% .*/\1/')
        STATUS=1
    else
        PING_MS=0
        LOSS=100
        STATUS=0
    fi

    metric "router_wan_ping{host=\"${HOST}\",iface=\"${IFACE_NAME}\"} ${PING_MS:-0}"
    metric "router_wan_loss{host=\"${HOST}\",iface=\"${IFACE_NAME}\"} ${LOSS:-0}"
    metric "router_wan_status{host=\"${HOST}\",iface=\"${IFACE_NAME}\"} ${STATUS}"
done
metric "# HELP router_wan_ping WAN ping latency in ms"
metric "# TYPE router_wan_ping gauge"
metric "# HELP router_wan_loss WAN packet loss percentage"
metric "# TYPE router_wan_loss gauge"
metric "# HELP router_wan_status WAN interface status (1=up 0=down)"
metric "# TYPE router_wan_status gauge"

# === TRAFFIC ===
for IFACE_DEV in eth1 lan5; do
    RX=$(cat /sys/class/net/${IFACE_DEV}/statistics/rx_bytes 2>/dev/null || echo "0")
    TX=$(cat /sys/class/net/${IFACE_DEV}/statistics/tx_bytes 2>/dev/null || echo "0")
    metric "router_traffic_rx{host=\"${HOST}\",iface=\"${IFACE_DEV}\"} ${RX}"
    metric "router_traffic_tx{host=\"${HOST}\",iface=\"${IFACE_DEV}\"} ${TX}"
done
metric "# HELP router_traffic_rx Interface RX bytes total"
metric "# TYPE router_traffic_rx counter"
metric "# HELP router_traffic_tx Interface TX bytes total"
metric "# TYPE router_traffic_tx counter"

# === WIFI CLIENTS ===
WIFI_2G=0; WIFI_5G=0
for IFACE_W in $(iwinfo 2>/dev/null | awk '/ESSID/{print $1}'); do
    FREQ=$(iwinfo "$IFACE_W" info 2>/dev/null | awk '/Channel/{print $4}' | tr -d '(')
    COUNT=$(iwinfo "$IFACE_W" assoclist 2>/dev/null | grep -c "dBm")
    if [ "${FREQ:-0}" -lt 3000 ] 2>/dev/null; then
        WIFI_2G=$((WIFI_2G + COUNT))
    else
        WIFI_5G=$((WIFI_5G + COUNT))
    fi
done
metric "# HELP router_clients_wifi_2g WiFi 2.4G connected clients"
metric "# TYPE router_clients_wifi_2g gauge"
metric "router_clients_wifi_2g{host=\"${HOST}\"} ${WIFI_2G}"
metric "# HELP router_clients_wifi_5g WiFi 5G connected clients"
metric "# TYPE router_clients_wifi_5g gauge"
metric "router_clients_wifi_5g{host=\"${HOST}\"} ${WIFI_5G}"
metric "# HELP router_clients_wifi_total Total WiFi clients"
metric "# TYPE router_clients_wifi_total gauge"
metric "router_clients_wifi_total{host=\"${HOST}\"} $((WIFI_2G + WIFI_5G))"

# DHCP clients by network
DHCP_LAN=$(cat /tmp/dhcp.leases 2>/dev/null | wc -l)
DHCP_IOT=$(cat /tmp/dhcp_iot.leases 2>/dev/null | wc -l)
DHCP_IOT=$(echo "$DHCP_IOT" | tr -d ' ')
metric "# HELP router_clients_dhcp_lan DHCP LAN clients"
metric "# TYPE router_clients_dhcp_lan gauge"
metric "router_clients_dhcp_lan{host=\"${HOST}\"} ${DHCP_LAN}"
metric "# HELP router_clients_dhcp_iot DHCP IoT clients"
metric "# TYPE router_clients_dhcp_iot gauge"
metric "router_clients_dhcp_iot{host=\"${HOST}\"} ${DHCP_IOT}"

# === WIFI QUALITY ===
WIFI_IFACES=$(iwinfo 2>/dev/null | awk '/ESSID/{print $1}')
W24=""; W5=""
for WI in $WIFI_IFACES; do
    WF=$(iwinfo "$WI" info 2>/dev/null | awk '/Channel/{print $4}' | tr -d '(')
    if [ "${WF:-0}" -lt 3000 ] 2>/dev/null; then
        [ -z "$W24" ] && W24="$WI"
    else
        [ -z "$W5" ] && W5="$WI"
    fi
done
for BAND in "2.4G" "5G"; do
    [ "$BAND" = "2.4G" ] && WIFACE="$W24" || WIFACE="$W5"
    if [ -n "$WIFACE" ]; then
        INFO=$(iwinfo "$WIFACE" info 2>/dev/null)
        NOISE=$(echo "$INFO" | grep "Noise:" | sed 's/.*Noise: \([-0-9]*\).*/\1/')
        SIGNAL=$(echo "$INFO" | grep "Signal:" | sed 's/.*Signal: \([-0-9]*\).*/\1/')
        CHAN_UTIL=$(iw dev "$WIFACE" survey dump 2>/dev/null | awk '/busy/{print $NF+0; exit}')
        metric "router_wifi_noise{host=\"${HOST}\",band=\"${BAND}\"} ${NOISE:-0}"
        metric "router_wifi_rssi{host=\"${HOST}\",band=\"${BAND}\"} ${SIGNAL:-0}"
        metric "router_wifi_chan_util{host=\"${HOST}\",band=\"${BAND}\"} ${CHAN_UTIL:-0}"
    fi
done
metric "# HELP router_wifi_noise WiFi noise floor in dBm"
metric "# TYPE router_wifi_noise gauge"
metric "# HELP router_wifi_rssi WiFi signal strength in dBm"
metric "# TYPE router_wifi_rssi gauge"
metric "# HELP router_wifi_chan_util WiFi channel utilization"
metric "# TYPE router_wifi_chan_util gauge"

# === DNS (AdGuardHome) ===
AGH_API="http://127.0.0.1:3000/control/stats"
AGH_STATS=$(wget -qO- "$AGH_API" 2>/dev/null)
if [ -n "$AGH_STATS" ]; then
    DNS_TOTAL=$(echo "$AGH_STATS" | jsonfilter -e '@.num_dns_queries' 2>/dev/null || echo "0")
    DNS_BLOCKED=$(echo "$AGH_STATS" | jsonfilter -e '@.num_blocked_filtering' 2>/dev/null || echo "0")
else
    DNS_TOTAL=0
    DNS_BLOCKED=0
fi
metric "# HELP router_dns_total Total DNS queries"
metric "# TYPE router_dns_total gauge"
metric "router_dns_total{host=\"${HOST}\"} ${DNS_TOTAL}"
metric "# HELP router_dns_blocked Blocked DNS queries"
metric "# TYPE router_dns_blocked gauge"
metric "router_dns_blocked{host=\"${HOST}\"} ${DNS_BLOCKED}"

# === SQM/Bufferbloat ===
# Check if SQM/cake is active
TC_OUT=$(tc -s qdisc show 2>/dev/null | grep -A5 "cake")
if [ -n "$TC_OUT" ]; then
    for DIR in dl ul; do
        DROPS=$(tc -s qdisc show 2>/dev/null | grep -A10 "cake" | awk '/dropped/{print $7+0; exit}')
        BACKLOG=$(tc -s qdisc show 2>/dev/null | grep -A10 "cake" | awk '/backlog/{print $2+0; exit}')
        metric "router_sqm_drops{host=\"${HOST}\",dir=\"${DIR}\"} ${DROPS:-0}"
        metric "router_sqm_queue_backlog_pkts{host=\"${HOST}\",dir=\"${DIR}\"} ${BACKLOG:-0}"
    done
    metric "# HELP router_sqm_drops SQM dropped packets"
    metric "# TYPE router_sqm_drops counter"
    metric "# HELP router_sqm_queue_backlog_pkts SQM queue backlog"
    metric "# TYPE router_sqm_queue_backlog_pkts gauge"
fi

# Output all metrics
printf "%b\n" "$METRICS"
