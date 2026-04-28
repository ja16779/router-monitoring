#!/bin/sh
# opkg-safe-upgrade.sh - Update OpenWrt packages without breaking GL.iNet GUI
# Usage: ./opkg-safe-upgrade.sh [--apply]
#   Without --apply: dry-run (shows what would be updated)
#   With --apply:    performs the actual upgrade

APPLY=0
[ "$1" = "--apply" ] && APPLY=1

# Packages to NEVER update (patterns)
EXCLUDE_PATTERNS="
^gl-
^glinet
^kmod-
^kernel
^base-files
^procd
^opkg
^busybox
^ubus
^uci
^netifd
^fstools
^ubox
^rpcd
^uhttpd
^nginx
^luajit
^lua-cjson
^libpcre
^libubus
^libubox
^libuci
^libpthread
^librt
^libgcc
^libc
"

log() { echo "[$(date '+%H:%M:%S')] $1"; }

log "=== OpenWrt Safe Package Upgrade ==="
log "Device: $(cat /etc/openwrt_release 2>/dev/null | grep DISTRIB_DESCRIPTION | cut -d\' -f2)"
log "Mode: $([ $APPLY -eq 1 ] && echo 'APPLY' || echo 'DRY-RUN')"
echo ""

# Update package lists
log "Updating package lists..."
opkg update >/dev/null 2>&1
if [ $? -ne 0 ]; then
    log "ERROR: opkg update failed"
    exit 1
fi

# Get upgradable packages
UPGRADABLE=$(opkg list-upgradable 2>/dev/null)
TOTAL=$(echo "$UPGRADABLE" | grep -c " - ")

if [ "$TOTAL" -eq 0 ]; then
    log "All packages are up to date."
    exit 0
fi

log "Found $TOTAL upgradable packages"
echo ""

# Build grep exclude pattern
EXCLUDE_GREP=$(echo "$EXCLUDE_PATTERNS" | grep -v '^$' | tr '\n' '|' | sed 's/|$//')

# Split into safe and excluded
SAFE_PKGS=$(echo "$UPGRADABLE" | grep -vE "$EXCLUDE_GREP")
EXCLUDED_PKGS=$(echo "$UPGRADABLE" | grep -E "$EXCLUDE_GREP")

SAFE_COUNT=$(echo "$SAFE_PKGS" | grep -c " - ")
EXCLUDED_COUNT=$(echo "$EXCLUDED_PKGS" | grep -c " - ")

# Show excluded packages
if [ "$EXCLUDED_COUNT" -gt 0 ]; then
    log "SKIPPING $EXCLUDED_COUNT packages (GL.iNet/kernel/system):"
    echo "$EXCLUDED_PKGS" | while read line; do
        pkg=$(echo "$line" | awk '{print $1}')
        echo "  SKIP  $pkg"
    done
    echo ""
fi

# Show safe packages
if [ "$SAFE_COUNT" -eq 0 ]; then
    log "No safe packages to upgrade."
    exit 0
fi

log "UPGRADING $SAFE_COUNT packages:"
echo "$SAFE_PKGS" | while read line; do
    pkg=$(echo "$line" | awk '{print $1}')
    old=$(echo "$line" | awk '{print $3}')
    new=$(echo "$line" | awk '{print $5}')
    echo "  UP    $pkg  $old -> $new"
done
echo ""

# Apply if requested
if [ $APPLY -eq 0 ]; then
    log "Dry-run complete. Run with --apply to perform upgrade."
    exit 0
fi

log "Starting upgrade..."
FAILED=0
SUCCESS=0

echo "$SAFE_PKGS" | while read line; do
    pkg=$(echo "$line" | awk '{print $1}')
    printf "  Installing %-40s " "$pkg..."
    OUTPUT=$(opkg upgrade "$pkg" 2>&1)
    if [ $? -eq 0 ]; then
        echo "OK"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "FAIL"
        echo "    $OUTPUT" | head -2
        FAILED=$((FAILED + 1))
    fi
done

echo ""
log "=== Upgrade complete ==="
log "Run 'logread | tail -50' to check for errors"
log "If anything is wrong, reboot: 'reboot'"
