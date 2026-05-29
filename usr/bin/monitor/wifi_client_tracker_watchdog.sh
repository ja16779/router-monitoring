#!/bin/bash
# WiFi Client Tracker Watchdog
# Verifica cada minuto que los 5 procesos hostapd_cli están activos
# Si se pierden (por wifi reload, reset de interfaces, etc), los reinicia automáticamente

HANDLER="/etc/hotplug.d/wifi/50-client-tracker"
INTERFACES="phy0-ap0 phy0-ap1 phy0-ap2 phy1-ap0 phy1-ap1"
LOG="/var/log/wifi_client_tracker.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WATCHDOG: $1" >> "$LOG"
}

# Count active hostapd_cli processes
ACTIVE=$(ps w 2>/dev/null | grep -c "hostapd_cli -a $HANDLER")

# Expected: 5 processes (one per interface)
if [ "$ACTIVE" -lt 5 ]; then
    log_message "⚠️  Only $ACTIVE/5 processes active — restarting service"

    # Kill any lingering processes
    killall -9 hostapd_cli 2>/dev/null || true
    sleep 1

    # Restart all processes
    for iface in $INTERFACES; do
        hostapd_cli -a "$HANDLER" -i "$iface" -B 2>/dev/null
    done

    sleep 1
    ACTIVE_NEW=$(ps w 2>/dev/null | grep -c "hostapd_cli -a $HANDLER")
    log_message "✅ Restarted — now $ACTIVE_NEW/5 processes active"
fi
