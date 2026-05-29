#!/bin/bash
# Update Beryl WiFi Tracker to correct 5-interface configuration

BERYL_IP="192.168.10.2"
BERYL_USER="root"
BERYL_PASS="admin"

echo "=== Updating Beryl WiFi Client Tracker ==="
echo "Target: $BERYL_IP"

# Update service init.d
echo "[1/4] Updating /etc/init.d/wifi-client-tracker..."
sshpass -p "$BERYL_PASS" ssh -o StrictHostKeyChecking=no "$BERYL_USER@$BERYL_IP" << 'EOF'
cat > /etc/init.d/wifi-client-tracker << 'SCRIPT'
#!/bin/sh /etc/rc.common
# WiFi Client Tracker Service — BERYL (GL-MT3000)
# Basado en chatgptwifinew.sh - simple y confiable

START=99
STOP=10

HANDLER="/etc/hotplug.d/wifi/50-client-tracker"
PIDFILE="/var/run/wifi_client_tracker.pid"

# Interfaces to monitor (Beryl tiene 5 APs activos)
INTERFACES="phy0-ap0 phy0-ap2 phy1-ap0 wlan0-1 wlan1-1"

start() {
    # Kill any existing processes
    killall -9 hostapd_cli 2>/dev/null || true
    sleep 1

    # Start hostapd_cli with handler for each interface
    for iface in $INTERFACES; do
        hostapd_cli -a "$HANDLER" -i "$iface" -B 2>/dev/null
    done

    sleep 1

    # Save PIDs
    pgrep hostapd_cli > "$PIDFILE" 2>/dev/null || echo "" > "$PIDFILE"
}

stop() {
    killall hostapd_cli 2>/dev/null || true
    rm -f "$PIDFILE"
}

restart() {
    stop
    sleep 1
    start
}

reload() {
    restart
}
SCRIPT
chmod +x /etc/init.d/wifi-client-tracker
EOF

# Update watchdog
echo "[2/4] Updating /usr/bin/monitor/wifi_client_tracker_watchdog_beryl.sh..."
sshpass -p "$BERYL_PASS" ssh -o StrictHostKeyChecking=no "$BERYL_USER@$BERYL_IP" << 'EOF'
mkdir -p /usr/bin/monitor
cat > /usr/bin/monitor/wifi_client_tracker_watchdog_beryl.sh << 'WATCHDOG'
#!/bin/bash
# WiFi Client Tracker Watchdog — BERYL (GL-MT3000)
# Verifica cada minuto que los procesos hostapd_cli están activos
# Si se pierden (por wifi reload, reset de interfaces, etc), los reinicia automáticamente

HANDLER="/etc/hotplug.d/wifi/50-client-tracker"
INTERFACES="phy0-ap0 phy0-ap2 phy1-ap0 wlan0-1 wlan1-1"
LOG="/var/log/wifi_client_tracker.log"
EXPECTED=5  # Beryl tiene 5 interfaces activas

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WATCHDOG: $1" >> "$LOG"
}

# Count active hostapd_cli processes
ACTIVE=$(ps w 2>/dev/null | grep -c "hostapd_cli -a $HANDLER")

# Expected: 5 processes
if [ "$ACTIVE" -lt $EXPECTED ]; then
    log_message "⚠️  Only $ACTIVE/$EXPECTED processes active — restarting service"

    # Kill any lingering processes
    killall -9 hostapd_cli 2>/dev/null || true
    sleep 1

    # Restart all processes
    for iface in $INTERFACES; do
        hostapd_cli -a "$HANDLER" -i "$iface" -B 2>/dev/null
    done

    sleep 1
    ACTIVE_NEW=$(ps w 2>/dev/null | grep -c "hostapd_cli -a $HANDLER")
    log_message "✅ Restarted — now $ACTIVE_NEW/$EXPECTED processes active"
fi
WATCHDOG
chmod +x /usr/bin/monitor/wifi_client_tracker_watchdog_beryl.sh
EOF

# Update handler with 5 interface mappings
echo "[3/4] Updating /etc/hotplug.d/wifi/50-client-tracker..."
sshpass -p "$BERYL_PASS" ssh -o StrictHostKeyChecking=no "$BERYL_USER@$BERYL_IP" << 'EOF'
cat > /etc/hotplug.d/wifi/50-client-tracker << 'HANDLER'
#!/bin/sh
# Script de notificacion WiFi via Telegram — BERYL (GL-MT3000)
# Notifica conexiones y desconexiones de dispositivos

# Configuracion
DHCP_LEASES="/tmp/dhcp.leases"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"

# Mapeo de interfaces a ESSID (Beryl: 5 APs activos)
get_essid() {
    case "$1" in
        phy0-ap0)  echo "Mega_2.4G_A2DF" ;;
        phy0-ap2)  echo "AXTEL_XTREMO" ;;
        phy1-ap0)  echo "AXTEL_XTREMO" ;;
        wlan0)     echo "IOT" ;;
        wlan0-1)   echo "IOT" ;;
        wlan1)     echo "AXTEL_XTREMO" ;;
        wlan1-1)   echo "Mega_5G_A2DF" ;;
        *)         echo "Unknown"; return 1 ;;
    esac
}

# Obtener informacion del cliente desde DHCP leases
get_client_info() {
    local mac="$1"
    local lease_line
    lease_line="$(grep -i "$mac" "$DHCP_LEASES")"

    CLIENT_IP="$(echo "$lease_line" | awk '{print $3}')"
    CLIENT_HOSTNAME="$(echo "$lease_line" | awk '{print $4}')"

    [ "$CLIENT_HOSTNAME" = "*" ] || [ -z "$CLIENT_HOSTNAME" ] && CLIENT_HOSTNAME="NONAME"
}

# Enviar mensaje a Telegram
send_telegram() {
    local message="$1"

    logger -p local0.info -t dhcp-notify "$message"

    [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && {
        logger -p local0.err -t dhcp-notify "Error: Token o chat_id vacio"
        return 1
    }

    curl -skim 10 \
        --data disable_notification="false" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$message" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

# Validar argumentos
[ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] && exit 1

INTERFACE="$1"
EVENT="$2"
MAC="$3"

ESSID="$(get_essid "$INTERFACE")" || exit 1
get_client_info "$MAC"

SAFE_HOSTNAME="$(echo "$CLIENT_HOSTNAME" | sed 's/[^a-zA-Z0-9]//g')"
TIMESTAMP="$(date '+%A %d-%b-%Y %T')"

case "$EVENT" in
    AP-STA-CONNECTED)
        BITRATE="$(iwinfo "$INTERFACE" info | awk '/Bit Rate:/{print $3, $4}')"
        send_telegram "<b>#${SAFE_HOSTNAME}</b> connected on <b>#${ESSID}</b>
<pre>
Time: ${TIMESTAMP}
Hostname: ${CLIENT_HOSTNAME}
IP Address: ${CLIENT_IP}
MAC Address: ${MAC}
ESSID: ${ESSID}
BitRate: ${BITRATE}
</pre>"
        ;;
    AP-STA-DISCONNECTED)
        send_telegram "<b>#${SAFE_HOSTNAME}</b> disconnected from <b>#${ESSID}</b>
<pre>
Time: ${TIMESTAMP}
Hostname: ${CLIENT_HOSTNAME}
IP Address: ${CLIENT_IP}
MAC Address: ${MAC}
ESSID: ${ESSID}
</pre>"
        ;;
esac
HANDLER
chmod +x /etc/hotplug.d/wifi/50-client-tracker
EOF

# Restart service
echo "[4/4] Restarting wifi-client-tracker service..."
sshpass -p "$BERYL_PASS" ssh -o StrictHostKeyChecking=no "$BERYL_USER@$BERYL_IP" << 'EOF'
/etc/init.d/wifi-client-tracker stop
sleep 2
/etc/init.d/wifi-client-tracker start
sleep 2
ps w | grep "hostapd_cli -a /etc/hotplug.d/wifi/50-client-tracker" | grep -v grep | wc -l
EOF

echo ""
echo "=== ✅ BERYL UPDATED ==="
echo "Verification: Check that 5 processes are now active with:"
echo "  ssh root@192.168.10.2 'ps w | grep hostapd_cli | grep -v grep | wc -l'"
echo ""
