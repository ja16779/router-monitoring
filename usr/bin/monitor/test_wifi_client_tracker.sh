#!/bin/bash
# WiFi Client Tracker Testing Suite
# Phase 3 Validation - Verify event capture and Telegram alerts work correctly

TARGET_ROUTER="${1:-192.168.10.1}"
TARGET_USER="root"
TARGET_PASS="admin"

echo "🧪 WiFi Client Tracker Testing Suite"
echo "====================================="
echo ""
echo "Router: $TARGET_ROUTER"
echo "Target: Flint-2 (GL-MT6000)"
echo ""

# Helper function for SSH
ssh_cmd() {
    sshpass -p "$TARGET_PASS" ssh -o StrictHostKeyChecking=no \
        "$TARGET_USER@$TARGET_ROUTER" "$@"
}

echo "📋 PRE-TEST CHECKS"
echo "---"

# 1. Check service is enabled
echo "✓ Checking service status..."
if ssh_cmd "/etc/init.d/wifi-client-tracker enabled" >/dev/null 2>&1; then
    echo "  ✅ Service enabled at boot"
else
    echo "  ⚠️  Service not enabled - running: ssh_cmd '/etc/init.d/wifi-client-tracker enable'"
    ssh_cmd "/etc/init.d/wifi-client-tracker enable"
fi

# 2. Check handler exists
echo "✓ Checking handler file..."
if ssh_cmd "test -f /etc/hotplug.d/wifi/50-client-tracker" >/dev/null 2>&1; then
    echo "  ✅ Handler installed"
else
    echo "  ❌ Handler missing!"
    exit 1
fi

# 3. Check log directory
echo "✓ Checking log directory..."
ssh_cmd "mkdir -p /var/log" >/dev/null 2>&1
echo "  ✅ Log directory ready"

# 4. Check Telegram config
echo "✓ Checking Telegram configuration..."
if ssh_cmd "grep -q 'TELEGRAM_TOKEN' /etc/hotplug.d/wifi/50-client-tracker" >/dev/null 2>&1; then
    echo "  ✅ Telegram token configured"
else
    echo "  ❌ Telegram token missing!"
    exit 1
fi

echo ""
echo "📊 TEST PROCEDURE"
echo "---"
echo ""
echo "Step 1: Open a terminal and run this command to monitor events:"
echo ""
echo "  ssh root@$TARGET_ROUTER 'tail -f /var/log/wifi_client_tracker.log'"
echo ""
echo "Step 2: When ready, connect a test device to WiFi:"
echo "  - Use any mobile phone, tablet, or laptop"
echo "  - Connect to any SSID: IOT, Mega_2.4G, AXTEL_XTREMO, Mega_5G, AXTEL_2G"
echo "  - Wait 1-2 seconds"
echo ""
echo "Step 3: Verify in the monitoring terminal you see:"
echo "  [timestamp] Event: interface=wlanX event=AP-STA-CONNECTED mac=xx:xx:xx:xx:xx:xx"
echo "  [timestamp] CONNECT: hostname (mac) to ssid"
echo ""
echo "Step 4: Verify Telegram alert received with:"
echo "  ✅ Device name as #safe_hostname"
echo "  ✅ SSID as #ssid"
echo "  ✅ All fields populated (IP, MAC, Signal, Band, Channel)"
echo "  ✅ Emojis visible"
echo ""
echo "Step 5: Disconnect the device from WiFi"
echo "  - Force disconnect or turn off WiFi"
echo "  - Wait 1-2 seconds"
echo ""
echo "Step 6: Verify disconnection alert:"
echo "  - Monitor terminal shows DISCONNECT event"
echo "  - Telegram alert received"
echo ""
echo "---"
echo ""
echo "⏱️  EXPECTED RESULTS"
echo "---"
echo ""
echo "✅ Connection Alert (example):"
echo ""
echo "  #iphone connected to #Mega_2.4G"
echo "  🕐 Time: 2026-05-24 20:50:15"
echo "  🖥️  Hostname: iphone"
echo "  📱 IP: 192.168.10.105"
echo "  🔗 MAC: aa:bb:cc:dd:ee:ff"
echo "  📡 SSID: Mega_2.4G"
echo "  📶 Band: 2.4GHz"
echo "  📊 Signal: -45dBm (91%)"
echo "  📍 Channel: 6"
echo ""
echo "✅ Disconnection Alert (example):"
echo ""
echo "  #iphone disconnected from #Mega_2.4G"
echo "  🕐 Time: 2026-05-24 20:51:30"
echo "  🖥️  Hostname: iphone"
echo "  📱 IP: 192.168.10.105"
echo "  🔗 MAC: aa:bb:cc:dd:ee:ff"
echo "  📡 SSID: Mega_2.4G"
echo ""
echo "---"
echo ""
echo "❌ TROUBLESHOOTING"
echo "---"
echo ""
echo "If no events appear in the log:"
echo ""
echo "1. Check service is running:"
echo "   ssh root@$TARGET_ROUTER '/etc/init.d/wifi-client-tracker status'"
echo ""
echo "2. Restart the service:"
echo "   ssh root@$TARGET_ROUTER '/etc/init.d/wifi-client-tracker restart'"
echo ""
echo "3. Check for errors in hostapd:"
echo "   ssh root@$TARGET_ROUTER 'logread | grep hostapd | tail -20'"
echo ""
echo "4. Manually trigger a test (if supported):"
echo "   ssh root@$TARGET_ROUTER '/etc/hotplug.d/wifi/50-client-tracker wlan0 AP-STA-CONNECTED aa:bb:cc:dd:ee:ff'"
echo ""
echo "If Telegram alert doesn't arrive:"
echo ""
echo "1. Check token and chat ID are correct:"
echo "   ssh root@$TARGET_ROUTER 'grep TELEGRAM /etc/hotplug.d/wifi/50-client-tracker'"
echo ""
echo "2. Test Telegram connectivity manually:"
echo "   ssh root@$TARGET_ROUTER << 'TGTEST'"
echo "   curl -s --data 'text=Test' --data 'chat_id=716542586' \\"
echo "     'https://api.telegram.org/botREDACTED_BOT_TOKEN/sendMessage'"
echo "   TGTEST"
echo ""
echo "3. Check internet connectivity:"
echo "   ssh root@$TARGET_ROUTER 'ping -c 2 api.telegram.org'"
echo ""
echo "---"
echo ""
echo "✅ Ready to test!"
echo ""
