#!/bin/sh
# LuCI package updater with Telegram notification

LOGFILE="/var/log/luci-upgrade.log"
LOGTAG="luci-upgrade"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"
DEVICE_NAME="$(uname -n)"
UPDATED_COUNT=0
FAILED_COUNT=0
UPDATED_LIST=""
FAILED_LIST=""

send_telegram() {
    curl -skim 10 \
        --data disable_notification="false" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

timestamp() {
    date '+%F %T'
}

log() {
    echo "$(timestamp) $*" | tee -a "$LOGFILE"
    logger -t "$LOGTAG" "$*"
}

upgrade_pkg() {
    local pkg="$1"
    log "Upgrading: $pkg"
    if opkg upgrade "$pkg" >>"$LOGFILE" 2>&1; then
        log "SUCCESS: $pkg"
        UPDATED_COUNT=$((UPDATED_COUNT + 1))
        UPDATED_LIST="${UPDATED_LIST}  ${pkg}\n"
    else
        log "ERROR: $pkg"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_LIST="${FAILED_LIST}  ${pkg}\n"
    fi
}

main() {
    > "$LOGFILE"
    log "=== LuCI upgrade started ==="

    log "Running opkg update..."
    if ! opkg update >>"$LOGFILE" 2>&1; then
        log "ERROR: opkg update failed"
        send_telegram "<b>#LuCI_Update ${DEVICE_NAME}</b>
<pre>opkg update failed</pre>"
        exit 1
    fi

    LUCI_PKGS=$(opkg list-upgradable | grep luci | awk '{print $1}')

    if [ -z "$LUCI_PKGS" ]; then
        log "No LuCI packages to upgrade."
        send_telegram "<b>#LuCI_Update ${DEVICE_NAME}</b>
<pre>No packages to upgrade</pre>"
        exit 0
    fi

    AVAILABLE=$(echo "$LUCI_PKGS" | wc -l)
    log "Found $AVAILABLE packages to upgrade"

    for pkg in $LUCI_PKGS; do
        upgrade_pkg "$pkg"
    done

    log "=== LuCI upgrade finished ==="
    log "Updated: $UPDATED_COUNT | Failed: $FAILED_COUNT"

    # Build Telegram message
    MSG="<b>#LuCI_Update ${DEVICE_NAME}</b>
<pre>
Updated: ${UPDATED_COUNT} | Failed: ${FAILED_COUNT}
</pre>"

    if [ $UPDATED_COUNT -gt 0 ]; then
        MSG="${MSG}
<b>Updated:</b>
<pre>
$(printf "$UPDATED_LIST")
</pre>"
    fi

    if [ $FAILED_COUNT -gt 0 ]; then
        MSG="${MSG}
<b>Failed:</b>
<pre>
$(printf "$FAILED_LIST")
</pre>"
    fi

    send_telegram "$MSG"
}

main
