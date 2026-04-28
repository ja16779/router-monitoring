#!/bin/sh
# install.sh
# Installation script for OpenWrt Threat Alert System
# Usage: ssh root@192.168.10.1 < install.sh
# Or: ./install.sh (with SFTP/SCP for files)

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  OpenWrt Threat Alert System - Installation                       ║"
echo "╚════════════════════════════════════════════════════════════════════╝"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Installation directory
INSTALL_DIR="/usr/local/lib/threat-alert"
CONFIG_DIR="/etc/threat-alert"
BIN_DIR="/usr/local/bin"

echo ""
echo "Installation Directory: $INSTALL_DIR"
echo "Config Directory: $CONFIG_DIR"
echo "Binaries: $BIN_DIR"
echo ""

# Check if running on OpenWrt
if [ ! -f /etc/openwrt_release ]; then
    echo "${RED}ERROR: This script must run on OpenWrt${NC}"
    exit 1
fi

echo "✓ OpenWrt detected"

# Create directories
echo "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "/var/log/threat-alert"

echo "✓ Directories created"

# Copy scripts to installation directory
echo "Installing scripts..."
for script in threat_feed_updater.sh anomaly_detector.sh; do
    if [ -f "./$script" ]; then
        cp "./$script" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/$script"
        ln -sf "$INSTALL_DIR/$script" "$BIN_DIR/$script" || true
        echo "  ✓ $script installed"
    else
        echo "${YELLOW}  ⚠ $script not found (will need manual install)${NC}"
    fi
done

# Install configuration
echo ""
echo "Setting up configuration..."
if [ ! -f "$CONFIG_DIR/config.sh" ]; then
    cp config.sh.template "$CONFIG_DIR/config.sh"
    echo "  ✓ config.sh created (needs editing)"
    echo ""
    echo "${YELLOW}IMPORTANT: Edit the configuration file:${NC}"
    echo "  vi $CONFIG_DIR/config.sh"
    echo ""
    echo "Required settings:"
    echo "  - TELEGRAM_BOT_TOKEN"
    echo "  - TELEGRAM_CHAT_ID"
    echo ""
else
    echo "  ✓ config.sh already exists"
fi

# Source config
. "$CONFIG_DIR/config.sh" 2>/dev/null || {
    echo "${RED}ERROR: Could not source configuration${NC}"
    exit 1
}

# Setup cron jobs
echo ""
echo "Setting up cron jobs..."

# Create crontab entries
CRON_FILE="/etc/crontabs/root"

# Backup existing crontab
[ -f "$CRON_FILE" ] && cp "$CRON_FILE" "$CRON_FILE.backup"

# Add threat feed updater (every 12 hours)
if ! grep -q "threat_feed_updater.sh" "$CRON_FILE" 2>/dev/null; then
    echo "0 */12 * * * $BIN_DIR/threat_feed_updater.sh >> /var/log/threat-alert/cron.log 2>&1" >> "$CRON_FILE"
    echo "  ✓ Threat feed updater scheduled (every 12h)"
fi

# Add anomaly detector (every 5 minutes)
if ! grep -q "anomaly_detector.sh" "$CRON_FILE" 2>/dev/null; then
    echo "*/5 * * * * $BIN_DIR/anomaly_detector.sh >> /var/log/threat-alert/cron.log 2>&1" >> "$CRON_FILE"
    echo "  ✓ Anomaly detector scheduled (every 5m)"
fi

# Restart cron
/etc/init.d/cron restart > /dev/null 2>&1 || echo "${YELLOW}  ⚠ Could not restart cron${NC}"

# Create init script for future use
echo ""
echo "Creating init script..."
cat > "$INSTALL_DIR/threat-alert.init" << 'INIT_SCRIPT'
#!/bin/sh /etc/rc.common
START=99
STOP=01

APP_NAME="threat-alert"
INSTALL_DIR="/usr/local/lib/threat-alert"
CONFIG_DIR="/etc/threat-alert"

start() {
    logger -t "$APP_NAME" "Starting Threat Alert System"

    # Run initial threat feed update
    "$INSTALL_DIR/threat_feed_updater.sh" 2>&1 | logger -t "$APP_NAME"

    return 0
}

stop() {
    logger -t "$APP_NAME" "Stopping Threat Alert System"
    return 0
}

restart() {
    stop
    sleep 1
    start
}

status() {
    echo "Threat Alert System Status"
    echo "============================"
    echo "Feed Update Script: $([ -x "$INSTALL_DIR/threat_feed_updater.sh" ] && echo 'OK' || echo 'MISSING')"
    echo "Anomaly Detector: $([ -x "$INSTALL_DIR/anomaly_detector.sh" ] && echo 'OK' || echo 'MISSING')"
    echo "Configuration: $([ -f "$CONFIG_DIR/config.sh" ] && echo 'OK' || echo 'MISSING')"
    echo ""
    echo "Recent logs:"
    tail -5 /var/log/threat-alert/updater.log 2>/dev/null || echo "(no logs yet)"
}
INIT_SCRIPT

chmod +x "$INSTALL_DIR/threat-alert.init"
echo "  ✓ Init script created at $INSTALL_DIR/threat-alert.init"

# Verify installation
echo ""
echo "Verifying installation..."
if [ -x "$INSTALL_DIR/threat_feed_updater.sh" ] && [ -x "$INSTALL_DIR/anomaly_detector.sh" ] && [ -f "$CONFIG_DIR/config.sh" ]; then
    echo "${GREEN}✓ Installation completed successfully!${NC}"
else
    echo "${RED}ERROR: Installation incomplete${NC}"
    exit 1
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  Installation Summary                                              ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Installation Directory: $INSTALL_DIR"
echo "Config File: $CONFIG_DIR/config.sh"
echo "Log Directory: /var/log/threat-alert/"
echo ""
echo "Next steps:"
echo "1. Edit configuration: vi $CONFIG_DIR/config.sh"
echo "2. Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID"
echo "3. Run manually: $BIN_DIR/threat_feed_updater.sh"
echo "4. Check logs: tail -f /var/log/threat-alert/updater.log"
echo ""
echo "Scheduled tasks:"
echo "  • Threat feed update: Every 12 hours"
echo "  • Anomaly detection: Every 5 minutes"
echo ""
echo "${GREEN}Installation complete!${NC}"
