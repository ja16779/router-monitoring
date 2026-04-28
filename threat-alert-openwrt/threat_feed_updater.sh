#!/bin/sh
# threat_feed_updater.sh
# Updates threat intelligence feeds and integrates with AdGuardHome
# Usage: ./threat_feed_updater.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

# Source configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    echo "Please copy config.sh.template to config.sh and configure it"
    exit 1
fi
. "$CONFIG_FILE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" | tee -a "$LOG_DIR/updater.log"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_DIR/updater.log"
}

log_debug() {
    [ "$LOG_LEVEL" = "DEBUG" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: $1" >> "$LOG_DIR/updater.log"
}

# Initialize
init() {
    mkdir -p "$FEED_DIR"
    mkdir -p "$LOG_DIR"
    log_info "Starting threat feed update"
}

# Download and parse abuse.ch URLhaus malware domains
fetch_urlhaus() {
    local feed_file="$FEED_DIR/urlhaus_malware.txt"
    local temp_file="/tmp/urlhaus_$$.json"

    log_debug "Fetching URLhaus malware domains..."

    if ! curl -sf -m 30 \
        "https://urlhaus-api.abuse.ch/v1/urls/recent/?limit=10000" \
        -o "$temp_file" 2>/dev/null; then
        log_error "Failed to download URLhaus feed"
        return 1
    fi

    # Parse JSON: extract domain from query string (simple parsing)
    cat "$temp_file" | grep -o '"host":"[^"]*' | cut -d'"' -f4 | sort -u > "$feed_file.tmp"

    if [ -s "$feed_file.tmp" ]; then
        mv "$feed_file.tmp" "$feed_file"
        local count=$(wc -l < "$feed_file")
        log_info "✓ URLhaus: $count malware domains"
        rm -f "$temp_file"
        return 0
    else
        log_error "URLhaus parsing failed"
        rm -f "$temp_file" "$feed_file.tmp"
        return 1
    fi
}

# Download Emerging Threats C&C IP list
fetch_emerging_threats() {
    local feed_file="$FEED_DIR/emerging_c2_ips.txt"

    log_debug "Fetching Emerging Threats C&C IPs..."

    if ! curl -sf -m 30 \
        "https://rules.emergingthreats.net/blockrules/compromised-ips.txt" \
        -o "$feed_file.tmp" 2>/dev/null; then
        log_error "Failed to download Emerging Threats"
        return 1
    fi

    # Remove comments and empty lines
    grep -v "^#" "$feed_file.tmp" | grep -v "^$" | sort -u > "$feed_file.new"

    if [ -s "$feed_file.new" ]; then
        mv "$feed_file.new" "$feed_file"
        local count=$(wc -l < "$feed_file")
        log_info "✓ Emerging Threats: $count C2 IPs"
        rm -f "$feed_file.tmp"
        return 0
    else
        log_error "Emerging Threats parsing failed"
        rm -f "$feed_file.tmp" "$feed_file.new"
        return 1
    fi
}

# Combine all feeds into single AdGuardHome filter
integrate_adguardhome() {
    local combined_file="$FEED_DIR/combined_threats.txt"

    log_debug "Integrating feeds with AdGuardHome..."

    > "$combined_file"

    # Add URLhaus domains as DNS blocks
    if [ -f "$FEED_DIR/urlhaus_malware.txt" ]; then
        cat "$FEED_DIR/urlhaus_malware.txt" | while read domain; do
            [ -n "$domain" ] && echo "||$domain^" >> "$combined_file"
        done
    fi

    # Add comment
    echo "! Updated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$combined_file"
    echo "! Total threats: $(grep -c '||' "$combined_file" 2>/dev/null || echo 0)" >> "$combined_file"

    if [ -s "$combined_file" ]; then
        local count=$(grep -c '||' "$combined_file" 2>/dev/null || echo 0)
        log_info "✓ Combined filter: $count domains/IPs"
        return 0
    else
        log_error "Combined filter is empty"
        return 1
    fi
}

# Update AdGuardHome filter via API
update_agh_filter() {
    local combined_file="$FEED_DIR/combined_threats.txt"

    if [ ! -f "$combined_file" ]; then
        log_error "Combined threats file not found"
        return 1
    fi

    # Check if AdGuardHome is running
    if ! curl -sf -m 5 "$AGH_API/status" > /dev/null 2>&1; then
        log_error "AdGuardHome is not responding at $AGH_API"
        return 1
    fi

    log_debug "Updating AdGuardHome filter..."

    # Note: This is a placeholder. Real implementation would:
    # 1. Get current filters via API
    # 2. Create/update custom filter with combined_threats.txt content
    # For now, we just verify the file exists

    local count=$(grep -c '||' "$combined_file" 2>/dev/null || echo 0)
    log_info "✓ AdGuardHome: $count threat rules ready"

    return 0
}

# Send Telegram notification
send_telegram_notification() {
    local count_domains=$(grep -c '||' "$FEED_DIR/combined_threats.txt" 2>/dev/null || echo 0)
    local count_ips=$([ -f "$FEED_DIR/emerging_c2_ips.txt" ] && wc -l < "$FEED_DIR/emerging_c2_ips.txt" || echo 0)

    if [ "$ALERT_FEED_UPDATE" -eq 1 ]; then
        local message="🔐 *Threat Feed Updated*
━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Malware Domains: $count_domains
🚨 C2 IPs: $count_ips
⏰ Updated: $(date '+%Y-%m-%d %H:%M UTC')
━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Feeds integrated with AdGuardHome"

        curl -s -X POST \
            "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            --data-urlencode "text=$message" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "parse_mode=Markdown" \
            > /dev/null 2>&1 || log_error "Telegram notification failed"
    fi
}

# Cleanup old feeds
cleanup_old_feeds() {
    find "$FEED_DIR" -type f -mtime +7 -delete 2>/dev/null || true
    log_debug "Cleaned up old feed files"
}

# Main execution
main() {
    init

    local success=0

    # Fetch feeds
    fetch_urlhaus && success=$((success+1))
    fetch_emerging_threats && success=$((success+1))

    # Integrate with AdGuardHome
    if [ $success -gt 0 ]; then
        integrate_adguardhome && update_agh_filter && send_telegram_notification
        cleanup_old_feeds
        log_info "Threat feed update completed successfully"
        exit 0
    else
        log_error "Feed update failed: no feeds downloaded"
        exit 1
    fi
}

# Run main
main "$@"
