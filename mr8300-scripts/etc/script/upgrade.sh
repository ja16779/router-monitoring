#!/bin/sh
#
# upgrade-luci.sh - Upgrade all LuCI packages with logging and dry-run support
#

opkg update

LOGFILE="/var/log/luci-upgrade.log"
DRYRUN=0   # set to 1 for dry-run mode

timestamp() {
    date '+%F %T'
}

log() {
    echo "$(timestamp) $*" | tee -a "$LOGFILE"
}

upgrade_pkg() {
    PKG="$1"
    if [ "$DRYRUN" -eq 1 ]; then
        log "[DRYRUN] Would upgrade: $PKG"
    else
        log "Upgrading: $PKG"
        if opkg upgrade "$PKG" >>"$LOGFILE" 2>&1; then
            log "SUCCESS: $PKG upgraded"
        else
            log "ERROR: Failed to upgrade $PKG"
        fi
    fi
}

main() {
    log "=== LuCI upgrade started ==="
    LUCI_PKGS=$(opkg list-upgradable | grep luci | awk '{print $1}')

    if [ -z "$LUCI_PKGS" ]; then
        log "No LuCI packages to upgrade."
        exit 0
    fi

    for PKG in $LUCI_PKGS; do
        upgrade_pkg "$PKG"
    done

    log "=== LuCI upgrade finished ==="
}

main "$@"
