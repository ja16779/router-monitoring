#!/bin/bash
# Deploy WiFi Client Tracker to Flint-2 and optional Beryl
# Installs hotplug handler and init service for AP-STA event monitoring

set -e

TARGET_ROUTER="${1:-192.168.10.1}"
TARGET_USER="root"
TARGET_PASS="admin"

HANDLER_SRC="./etc/hotplug.d/wifi/50-client-tracker"
SERVICE_SRC="./etc/init.d/wifi-client-tracker"
UCIDEF_SRC="./etc/uci-defaults/99-client-tracker"

echo "📡 Deploying WiFi Client Tracker to $TARGET_ROUTER..."

# Check if source files exist
for file in "$HANDLER_SRC" "$SERVICE_SRC" "$UCIDEF_SRC"; do
    if [ ! -f "$file" ]; then
        echo "❌ ERROR: Source file not found: $file"
        exit 1
    fi
done

# SSH commands to execute on router
ssh_deploy() {
    sshpass -p "$TARGET_PASS" ssh -o StrictHostKeyChecking=no \
        "$TARGET_USER@$TARGET_ROUTER" "$@"
}

# Deploy handler
echo "📝 Deploying hotplug handler..."
sshpass -p "$TARGET_PASS" scp -o StrictHostKeyChecking=no "$HANDLER_SRC" \
    "$TARGET_USER@$TARGET_ROUTER:/etc/hotplug.d/wifi/50-client-tracker"

ssh_deploy "chmod +x /etc/hotplug.d/wifi/50-client-tracker"
echo "✅ Handler deployed"

# Deploy service
echo "📝 Deploying init service..."
sshpass -p "$TARGET_PASS" scp -o StrictHostKeyChecking=no "$SERVICE_SRC" \
    "$TARGET_USER@$TARGET_ROUTER:/etc/init.d/wifi-client-tracker"

ssh_deploy "chmod +x /etc/init.d/wifi-client-tracker"
ssh_deploy "/etc/init.d/wifi-client-tracker enable"
echo "✅ Service deployed and enabled"

# Deploy UCI defaults for persistence
echo "📝 Deploying UCI defaults (persistence)..."
sshpass -p "$TARGET_PASS" scp -o StrictHostKeyChecking=no "$UCIDEF_SRC" \
    "$TARGET_USER@$TARGET_ROUTER:/etc/uci-defaults/99-client-tracker"

ssh_deploy "chmod +x /etc/uci-defaults/99-client-tracker"
echo "✅ Persistence script deployed"

# Create log directory
ssh_deploy "mkdir -p /var/log"

# Start the service
echo "🚀 Starting service..."
ssh_deploy "/etc/init.d/wifi-client-tracker start"
echo "✅ Service started"

# Verify deployment
echo ""
echo "✔️  Verification:"
echo "---"
ssh_deploy "ls -la /etc/hotplug.d/wifi/50-client-tracker"
ssh_deploy "ls -la /etc/init.d/wifi-client-tracker"
ssh_deploy "/etc/init.d/wifi-client-tracker status 2>/dev/null || echo 'Status: Service installed'"
echo ""
echo "📋 To monitor events in real-time:"
echo "   ssh root@$TARGET_ROUTER 'tail -f /var/log/wifi_client_tracker.log'"
echo ""
echo "📋 To test connection tracking:"
echo "   1. Connect a device to WiFi"
echo "   2. Check Telegram for alert with full device info"
echo "   3. Disconnect and verify disconnection alert"
echo ""
echo "✅ Deployment complete!"
