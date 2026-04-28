#!/bin/sh
# security_monitor.sh
# Real-time security monitoring and attack detection
# Shows what's happening on your network RIGHT NOW
# Usage: ./security_monitor.sh [--live|--dashboard|--telegram]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

# Source configuration
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="/etc/threat-alert/config.sh"
fi

if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════
# SECURITY METRICS
# ═══════════════════════════════════════════════════════════════════════════

get_firewall_blocks() {
    # Count firewall drops in last 5 minutes
    logread 2>/dev/null | grep -i "fw.*drop\|fw.*reject" | tail -100 | wc -l
}

get_ssh_attempts() {
    # Count failed SSH attempts in last 5 minutes
    logread 2>/dev/null | grep -i "invalid user\|failed password\|authentication failure" | tail -50 | wc -l
}

get_dns_queries() {
    # Count DNS queries in last 5 minutes (from dnsmasq)
    logread 2>/dev/null | grep "query\[" | tail -200 | wc -l
}

get_connection_count() {
    # Count active connections
    netstat -tn 2>/dev/null | grep ESTABLISHED | wc -l
}

get_unique_sources() {
    # Count unique source IPs trying to connect
    netstat -tn 2>/dev/null | grep -oE "^tcp.*[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | \
        awk '{print $5}' | cut -d: -f1 | sort -u | wc -l
}

get_top_talkers() {
    # Get top talkers (devices sending most traffic)
    netstat -tn 2>/dev/null | grep ESTABLISHED | \
        awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -5
}

get_suspicious_ports() {
    # Check for connections to unusual ports
    netstat -tn 2>/dev/null | grep -E ":(445|3389|22|23|8080)" | wc -l
}

get_blocked_ips() {
    # Count IPs blocked from feeds
    [ -f /etc/threat-alert/feeds/emerging_c2_ips.txt ] && \
        wc -l < /etc/threat-alert/feeds/emerging_c2_ips.txt || echo 0
}

# ═══════════════════════════════════════════════════════════════════════════
# THREAT LEVEL CALCULATION
# ═══════════════════════════════════════════════════════════════════════════

calculate_threat_level() {
    local fw_blocks=$(get_firewall_blocks)
    local ssh_attempts=$(get_ssh_attempts)
    local connections=$(get_connection_count)

    local threat_score=0

    # Firewall blocks
    [ $fw_blocks -gt 50 ] && threat_score=$((threat_score + 30))
    [ $fw_blocks -gt 100 ] && threat_score=$((threat_score + 30))

    # SSH attempts
    [ $ssh_attempts -gt 5 ] && threat_score=$((threat_score + 20))
    [ $ssh_attempts -gt 20 ] && threat_score=$((threat_score + 30))

    # Connections
    [ $connections -gt 100 ] && threat_score=$((threat_score + 10))
    [ $connections -gt 200 ] && threat_score=$((threat_score + 20))

    echo $threat_score
}

get_threat_color() {
    local score=$1

    if [ $score -lt 20 ]; then
        echo "$GREEN"
    elif [ $score -lt 50 ]; then
        echo "$YELLOW"
    else
        echo "$RED"
    fi
}

get_threat_label() {
    local score=$1

    if [ $score -lt 20 ]; then
        echo "🟢 NORMAL"
    elif [ $score -lt 50 ]; then
        echo "🟡 SOSPECHOSO"
    else
        echo "🔴 CRÍTICO - POSIBLE ATAQUE"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# DISPLAY: LIVE DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════

show_live_dashboard() {
    clear

    while true; do
        clear

        local threat_score=$(calculate_threat_level)
        local threat_color=$(get_threat_color $threat_score)
        local threat_label=$(get_threat_label $threat_score)

        local fw_blocks=$(get_firewall_blocks)
        local ssh_attempts=$(get_ssh_attempts)
        local dns_queries=$(get_dns_queries)
        local connections=$(get_connection_count)
        local unique_sources=$(get_unique_sources)
        local suspicious=$(get_suspicious_ports)
        local blocked_ips=$(get_blocked_ips)

        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║  🛡️  SECURITY MONITOR - REAL-TIME THREAT LEVEL                 ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""

        # Threat Level
        echo "┌────────────────────────────────────────────────────────────────┐"
        printf "│ ${threat_color}%-66s${NC}│\n" "$(printf '%s [%d/100]' "$threat_label" "$threat_score")"
        echo "└────────────────────────────────────────────────────────────────┘"
        echo ""

        # Network Activity
        echo "📊 ACTIVIDAD DE RED (últimos 5 minutos):"
        echo "   • Conexiones activas:      $connections"
        echo "   • IPs únicas:              $unique_sources"
        echo "   • Queries DNS:             $dns_queries"
        echo ""

        # Security Events
        echo "🚨 EVENTOS DE SEGURIDAD:"

        if [ $fw_blocks -gt 0 ]; then
            printf "   • Firewall blocks:         ${RED}%d${NC}\n" $fw_blocks
        else
            printf "   • Firewall blocks:         ${GREEN}%d${NC}\n" $fw_blocks
        fi

        if [ $ssh_attempts -gt 0 ]; then
            printf "   • SSH failed attempts:     ${RED}%d${NC}\n" $ssh_attempts
        else
            printf "   • SSH failed attempts:     ${GREEN}%d${NC}\n" $ssh_attempts
        fi

        printf "   • Conexiones a puertos raros: %d\n" $suspicious
        echo ""

        # Threat Intelligence
        echo "🎯 INTELIGENCIA DE AMENAZAS:"
        echo "   • IPs en blacklist:        $blocked_ips (Emerging Threats)"

        # Top Talkers
        echo ""
        echo "🔝 TOP TALKERS (más activos):"
        get_top_talkers | while read count ip; do
            printf "   • %-15s %d conexiones\n" "$ip" "$count"
        done

        # Last Events
        echo ""
        echo "📋 ÚLTIMOS EVENTOS:"
        logread 2>/dev/null | grep -E "fw.*drop|invalid user|failed pass|query\[" | \
            tail -5 | sed 's/^/   /'

        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Actualización cada 5 segundos... (Ctrl+C para salir)"
        echo "Última actualización: $(date '+%Y-%m-%d %H:%M:%S')"

        sleep 5
    done
}

# ═══════════════════════════════════════════════════════════════════════════
# SEND TELEGRAM ALERT
# ═══════════════════════════════════════════════════════════════════════════

send_alert() {
    local threat_label=$1
    local threat_score=$2

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        return
    fi

    local fw_blocks=$(get_firewall_blocks)
    local ssh_attempts=$(get_ssh_attempts)
    local message="🚨 *SECURITY ALERT*
━━━━━━━━━━━━━━━━━━━━━━━━
Status: ${threat_label}
Score: ${threat_score}/100

Events (5min):
• Firewall blocks: $fw_blocks
• SSH attempts: $ssh_attempts
• Connections: $(get_connection_count)

Time: $(date '+%Y-%m-%d %H:%M UTC')
Router: $(hostname)"

    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "text=$message" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=Markdown" \
        > /dev/null 2>&1
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════

case "${1:-live}" in
    --live)
        show_live_dashboard
        ;;

    --check)
        # Quick one-time check
        threat_score=$(calculate_threat_level)
        threat_label=$(get_threat_label $threat_score)

        echo "Threat Level: $threat_label ($threat_score/100)"
        echo "Firewall blocks: $(get_firewall_blocks)"
        echo "SSH attempts: $(get_ssh_attempts)"
        echo "Active connections: $(get_connection_count)"
        ;;

    --alert)
        # Send alert if threshold exceeded
        threat_score=$(calculate_threat_level)

        if [ $threat_score -gt 50 ]; then
            threat_label=$(get_threat_label $threat_score)
            send_alert "$threat_label" "$threat_score"
            echo "Alert sent"
        fi
        ;;

    *)
        echo "Usage: $0 [--live|--check|--alert]"
        echo ""
        echo "Options:"
        echo "  --live    Live dashboard (updates every 5 seconds)"
        echo "  --check   One-time threat level check"
        echo "  --alert   Send Telegram alert if threat detected"
        ;;
esac
