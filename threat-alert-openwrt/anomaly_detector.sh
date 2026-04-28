#!/bin/sh
# anomaly_detector.sh
# Detects suspicious network patterns and behaviors
# Usage: ./anomaly_detector.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

# Source configuration
if [ ! -f "$CONFIG_FILE" ]; then
    exit 1
fi
. "$CONFIG_FILE"

LOG_FILE="$LOG_DIR/anomaly.log"

# Logging
log_anomaly() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Initialize
mkdir -p "$LOG_DIR"

# ═══════════════════════════════════════════════════════════════════════════
# 1. DETECT PORT SCANNING (multiple new ports from same IP)
# ═══════════════════════════════════════════════════════════════════════════

detect_port_scanning() {
    [ "$ENABLE_ANOMALY_DETECTION" -eq 0 ] && return

    # Check /proc/net/nf_conntrack for unusual connection patterns
    if [ ! -f /proc/net/nf_conntrack ]; then
        return
    fi

    # Simplified: count unique ports per source IP in last 5 minutes
    local threshold=$MAX_NEW_PORTS

    # Parse conntrack for new TCP connections
    # Format: ipv4 2 tcp 6 ... src=192.168.10.5 dst=8.8.8.8 sport=12345 dport=443
    netstat -tnp 2>/dev/null | awk '$6 ~ /ESTABLISHED|SYN_SENT/ { gsub(/:/, " "); print $5, $6 }' | \
    while read src_ip src_port dst_ip dst_port; do
        [ -z "$dst_port" ] && continue

        # Count unique destination ports per source IP
        unique_ports=$(netstat -tn 2>/dev/null | awk -v ip="$src_ip" '$5 ~ ip { gsub(/:/, " "); print $NF }' | sort -u | wc -l)

        if [ "$unique_ports" -gt "$threshold" ]; then
            local alert="🔴 PORT SCANNING DETECTED
IP: $src_ip
Unique Ports: $unique_ports (threshold: $threshold)
Time: $(date '+%Y-%m-%d %H:%M:%S')"

            log_anomaly "$alert"
            [ "$ALERT_PORT_SCANNING" -eq 1 ] && send_alert "$alert" "port_scanning"
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# 2. DETECT SSH BRUTE FORCE
# ═══════════════════════════════════════════════════════════════════════════

detect_ssh_bruteforce() {
    [ "$ENABLE_ANOMALY_DETECTION" -eq 0 ] && return
    [ "$ALERT_SSH_BRUTEFORCE" -eq 0 ] && return

    # Check system logs for SSH failed authentication
    local threshold=$SSH_FAILED_THRESHOLD

    if command -v logread > /dev/null 2>&1; then
        # Get recent logs
        local failed_attempts=$(logread 2>/dev/null | grep -i "invalid user\|failed password" | wc -l)

        if [ "$failed_attempts" -gt "$threshold" ]; then
            # Extract attacking IP
            local attacker_ip=$(logread 2>/dev/null | grep -i "invalid user\|failed password" | \
                grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -1)

            local alert="⚠️ SSH BRUTE FORCE DETECTED
IP: ${attacker_ip:-unknown}
Failed Attempts: $failed_attempts (threshold: $threshold)
Time: $(date '+%Y-%m-%d %H:%M:%S')"

            log_anomaly "$alert"
            send_alert "$alert" "ssh_bruteforce"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 3. DETECT DNS FLOODING
# ═══════════════════════════════════════════════════════════════════════════

detect_dns_flooding() {
    [ "$ENABLE_ANOMALY_DETECTION" -eq 0 ] && return
    [ "$ALERT_DNS_FLOODING" -eq 0 ] && return

    local threshold=$DNS_QUERY_THRESHOLD

    # Check dnsmasq logs for unusual query patterns
    if command -v logread > /dev/null 2>&1; then
        # Count DNS queries in last 10 seconds
        local recent_queries=$(logread 2>/dev/null | grep "query\[" | wc -l)

        if [ "$recent_queries" -gt "$threshold" ]; then
            # Find source IP with most queries
            local top_ip=$(logread 2>/dev/null | grep "query\[" | \
                grep -oE "from [0-9.]+\|[0-9.]+" | cut -d' ' -f2 | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')

            local alert="🌊 DNS FLOODING DETECTED
IP: ${top_ip:-unknown}
Queries: $recent_queries (threshold: $threshold)
Time: $(date '+%Y-%m-%d %H:%M:%S')"

            log_anomaly "$alert"
            send_alert "$alert" "dns_flooding"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# 4. DETECT FIREWALL BLOCKS ANOMALY
# ═══════════════════════════════════════════════════════════════════════════

detect_firewall_anomaly() {
    [ "$ENABLE_ANOMALY_DETECTION" -eq 0 ] && return
    [ "$ALERT_FIREWALL_BLOCK" -eq 0 ] && return

    # Count firewall drop/reject rules
    if command -v logread > /dev/null 2>&1; then
        local blocks=$(logread 2>/dev/null | grep -i "fw.*drop\|fw.*reject" | wc -l)

        # Only alert if significant (>100 in a short period = anomaly)
        if [ "$blocks" -gt 100 ]; then
            local alert="🚫 FIREWALL ANOMALY
Blocks: $blocks
This may indicate scanning or attack
Time: $(date '+%Y-%m-%d %H:%M:%S')"

            log_anomaly "$alert"
            send_alert "$alert" "firewall_anomaly"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# SEND ALERT
# ═══════════════════════════════════════════════════════════════════════════

send_alert() {
    local message="$1"
    local alert_type="$2"

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        return
    fi

    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "text=$message" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=Markdown" \
        > /dev/null 2>&1 || log_anomaly "Telegram send failed"
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════

main() {
    # Run all detectors
    detect_port_scanning
    detect_ssh_bruteforce
    detect_dns_flooding
    detect_firewall_anomaly
}

main "$@"
