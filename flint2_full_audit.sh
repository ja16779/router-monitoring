#!/bin/bash
# ============================================================
# Flint-2 Full Configuration Audit
# Router: 192.168.10.1 | User: root
# ============================================================

HOST="192.168.10.1"
USER="root"
PASS="admin"

# Use sshpass for non-interactive SSH
SSH="sshpass -p $PASS ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${USER}@${HOST}"

echo "============================================================"
echo "  FLINT-2 FULL CONFIGURATION AUDIT"
echo "  $(date)"
echo "============================================================"

# --- 1. SYSTEM INFO ---
echo ""
echo "============================================================"
echo "  1. SYSTEM INFORMATION"
echo "============================================================"

echo "--- Hostname & Board ---"
$SSH "cat /etc/board.json 2>/dev/null | head -20; echo '---'; uname -a; cat /etc/openwrt_release 2>/dev/null; cat /etc/glversion 2>/dev/null; cat /tmp/sysinfo/board_name 2>/dev/null; cat /tmp/sysinfo/model 2>/dev/null"

echo ""
echo "--- Uptime & Load ---"
$SSH "uptime; cat /proc/loadavg"

echo ""
echo "--- CPU Info ---"
$SSH "cat /proc/cpuinfo | grep -E 'processor|model name|cpu MHz|BogoMIPS' | head -20"

echo ""
echo "--- Memory ---"
$SSH "free -m; echo '---'; cat /proc/meminfo | head -10"

echo ""
echo "--- Storage ---"
$SSH "df -h; echo '---'; mount | grep -v tmpfs"

echo ""
echo "--- Kernel Version & Modules ---"
$SSH "uname -r; lsmod | head -30"

# --- 2. NETWORK INTERFACES ---
echo ""
echo "============================================================"
echo "  2. NETWORK INTERFACES"
echo "============================================================"

echo "--- IP Addresses ---"
$SSH "ip addr show"

echo ""
echo "--- Routing Table ---"
$SSH "ip route show; echo '--- IPv6 ---'; ip -6 route show 2>/dev/null | head -20"

echo ""
echo "--- ARP Table ---"
$SSH "ip neigh show | head -30"

echo ""
echo "--- Bridge Info ---"
$SSH "brctl show 2>/dev/null; echo '---'; bridge link show 2>/dev/null"

echo ""
echo "--- Interface Stats ---"
$SSH "cat /proc/net/dev"

# --- 3. UCI NETWORK CONFIG ---
echo ""
echo "============================================================"
echo "  3. UCI NETWORK CONFIGURATION"
echo "============================================================"

echo "--- /etc/config/network ---"
$SSH "cat /etc/config/network"

echo ""
echo "--- Network Status ---"
$SSH "ubus call network.interface.wan status 2>/dev/null | head -30; echo '---'; ubus call network.interface.lan status 2>/dev/null | head -30"

# --- 4. FIREWALL ---
echo ""
echo "============================================================"
echo "  4. FIREWALL CONFIGURATION"
echo "============================================================"

echo "--- /etc/config/firewall ---"
$SSH "cat /etc/config/firewall"

echo ""
echo "--- iptables rules ---"
$SSH "iptables -L -n -v 2>/dev/null | head -60; echo '--- NAT ---'; iptables -t nat -L -n -v 2>/dev/null | head -40"

echo ""
echo "--- nftables rules ---"
$SSH "nft list ruleset 2>/dev/null | head -100"

# --- 5. DHCP & DNS ---
echo ""
echo "============================================================"
echo "  5. DHCP & DNS CONFIGURATION"
echo "============================================================"

echo "--- /etc/config/dhcp ---"
$SSH "cat /etc/config/dhcp"

echo ""
echo "--- DNS resolv ---"
$SSH "cat /etc/resolv.conf; echo '---'; cat /tmp/resolv.conf.d/resolv.conf.auto 2>/dev/null"

echo ""
echo "--- Active DHCP Leases ---"
$SSH "cat /tmp/dhcp.leases 2>/dev/null; echo '---'; cat /var/dhcp.leases 2>/dev/null"

# --- 6. WIRELESS ---
echo ""
echo "============================================================"
echo "  6. WIRELESS CONFIGURATION"
echo "============================================================"

echo "--- /etc/config/wireless ---"
$SSH "cat /etc/config/wireless"

echo ""
echo "--- WiFi Status ---"
$SSH "iwinfo 2>/dev/null; echo '---'; iw dev 2>/dev/null"

echo ""
echo "--- Connected WiFi Clients ---"
$SSH "for iface in \$(iwinfo 2>/dev/null | grep ESSID | awk '{print \$1}'); do echo \"=== \$iface ===\"; iwinfo \$iface assoclist 2>/dev/null; done"

# --- 7. ADGUARD HOME ---
echo ""
echo "============================================================"
echo "  7. ADGUARD HOME"
echo "============================================================"

echo "--- AdGuard Status ---"
$SSH "pgrep -a AdGuardHome 2>/dev/null; echo '---'; ls -la /etc/AdGuardHome/ 2>/dev/null; ls -la /opt/AdGuardHome/ 2>/dev/null"

echo ""
echo "--- AdGuard Config (key parts) ---"
$SSH "cat /etc/AdGuardHome/config.yaml 2>/dev/null || cat /opt/AdGuardHome/AdGuardHome.yaml 2>/dev/null" 2>/dev/null | head -100

# --- 8. VPN (WireGuard / OpenVPN / Tailscale) ---
echo ""
echo "============================================================"
echo "  8. VPN CONFIGURATION"
echo "============================================================"

echo "--- WireGuard ---"
$SSH "wg show 2>/dev/null; echo '---'; cat /etc/config/wireguard_* 2>/dev/null; ls /etc/wireguard/ 2>/dev/null"

echo ""
echo "--- Tailscale ---"
$SSH "tailscale status 2>/dev/null; echo '---'; tailscale version 2>/dev/null"

echo ""
echo "--- OpenVPN ---"
$SSH "cat /etc/config/openvpn 2>/dev/null; pgrep -a openvpn 2>/dev/null"

# --- 9. SERVICES & PROCESSES ---
echo ""
echo "============================================================"
echo "  9. RUNNING SERVICES & PROCESSES"
echo "============================================================"

echo "--- Init Scripts (enabled) ---"
$SSH "ls /etc/rc.d/ 2>/dev/null"

echo ""
echo "--- Top Processes ---"
$SSH "ps aux 2>/dev/null || ps w 2>/dev/null" | head -50

echo ""
echo "--- Listening Ports ---"
$SSH "netstat -tlnp 2>/dev/null || ss -tlnp 2>/dev/null"

# --- 10. CRONTAB ---
echo ""
echo "============================================================"
echo "  10. CRONTAB"
echo "============================================================"
$SSH "crontab -l 2>/dev/null; echo '---'; cat /etc/crontabs/root 2>/dev/null"

# --- 11. SYSTEM CONFIG ---
echo ""
echo "============================================================"
echo "  11. SYSTEM CONFIG"
echo "============================================================"

echo "--- /etc/config/system ---"
$SSH "cat /etc/config/system"

echo ""
echo "--- /etc/config/dropbear ---"
$SSH "cat /etc/config/dropbear"

# --- 12. GL.iNet SPECIFIC ---
echo ""
echo "============================================================"
echo "  12. GL.iNet SPECIFIC CONFIG"
echo "============================================================"

echo "--- GL.iNet Config Files ---"
$SSH "ls /etc/config/gl* 2>/dev/null; echo '---'; ls /etc/config/glinet* 2>/dev/null"

echo ""
echo "--- GL.iNet Repeater/Tethering ---"
$SSH "cat /etc/config/glconfig 2>/dev/null | head -50"

echo ""
echo "--- GL.iNet GoodCloud ---"
$SSH "cat /etc/config/rtty 2>/dev/null"

# --- 13. INSTALLED PACKAGES ---
echo ""
echo "============================================================"
echo "  13. INSTALLED PACKAGES"
echo "============================================================"
$SSH "opkg list-installed 2>/dev/null" | head -100

# --- 14. LOGS ---
echo ""
echo "============================================================"
echo "  14. RECENT SYSTEM LOGS"
echo "============================================================"
$SSH "logread -l 50 2>/dev/null"

echo ""
echo "--- Kernel Log (last 30 lines) ---"
$SSH "dmesg | tail -30"

# --- 15. HARDWARE / THERMAL ---
echo ""
echo "============================================================"
echo "  15. HARDWARE & THERMAL"
echo "============================================================"

echo "--- CPU Temperature ---"
$SSH "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null; echo '---'; for z in /sys/class/thermal/thermal_zone*/type; do echo \"\$z: \$(cat \$z)\"; done 2>/dev/null"

echo ""
echo "--- USB Devices ---"
$SSH "lsusb 2>/dev/null; echo '---'; ls /sys/bus/usb/devices/ 2>/dev/null"

echo ""
echo "--- LED Config ---"
$SSH "cat /etc/config/system | grep -A5 'config led'"

# --- 16. QoS / SQM ---
echo ""
echo "============================================================"
echo "  16. QoS / SQM"
echo "============================================================"
$SSH "cat /etc/config/sqm 2>/dev/null; echo '---'; cat /etc/config/qos 2>/dev/null"

# --- 17. MWAN3 / LOAD BALANCING ---
echo ""
echo "============================================================"
echo "  17. MWAN3 / LOAD BALANCING"
echo "============================================================"
$SSH "cat /etc/config/mwan3 2>/dev/null; echo '---'; mwan3 status 2>/dev/null | head -30"

echo ""
echo "============================================================"
echo "  AUDIT COMPLETE - $(date)"
echo "============================================================"
