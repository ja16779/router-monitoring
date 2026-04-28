#!/usr/bin/env python3
import paramiko
import json
import sys

def run_ssh_command(ssh, command):
    """Run command via SSH and return output"""
    stdin, stdout, stderr = ssh.exec_command(command, timeout=30)
    return stdout.read().decode().strip()

def check_flint2():
    """Run all checks on Flint-2"""
    print("=" * 60)
    print("🔍 FLINT-2 (GL-MT6000) - 192.168.10.1")
    print("=" * 60)

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect('192.168.10.1', username='root', password='admin', timeout=10)
    except Exception as e:
        print(f"❌ ERROR connecting to Flint-2: {e}")
        return

    results = []

    # Services check
    print("\n📋 Services Status:")
    for svc in ['adguardhome', 'tailscaled', 'dnsmasq', 'mdns-repeater']:
        output = run_ssh_command(ssh, f'pidof {svc} > /dev/null 2>&1 && echo "running" || echo "STOPPED"')
        status = "✅ OK" if output == "running" else "❌ STOPPED"
        print(f"  {svc:20} {status}")
        results.append(('service_' + svc, output == "running"))

    # Usteer check (should be removed)
    output = run_ssh_command(ssh, 'pidof usteerd > /dev/null 2>&1 && echo "RUNNING" || echo "removed"')
    status = "✅ removed" if output == "removed" else "⚠️ RUNNING (should be removed)"
    print(f"  {'usteer':20} {status}")

    # MWAN3 status
    print("\n🌐 MWAN3 Status:")
    output = run_ssh_command(ssh, 'mwan3 status 2>&1 | grep -E "online|offline"')
    for line in output.split('\n'):
        if line.strip():
            status = "✅" if "online" in line else "❌"
            print(f"  {status} {line.strip()}")

    # Tailscale
    print("\n🔒 Tailscale Status:")
    output = run_ssh_command(ssh, 'tailscale status --json')
    try:
        ts_data = json.loads(output)
        backend_state = ts_data.get('BackendState', 'unknown')
        status = "✅" if backend_state == "Running" else "❌"
        print(f"  {status} BackendState: {backend_state}")

        # Check exit node
        self_data = ts_data.get('Self', {})
        if self_data.get('ExitNode'):
            print(f"  ✅ Exit node: advertised")
        else:
            print(f"  ⚠️ Exit node: NOT advertised")
    except:
        print(f"  ⚠️ Could not parse tailscale status")

    # Table 52 and ip rule
    output = run_ssh_command(ssh, 'ip route show table 52 | wc -l')
    print(f"  Table 52 routes: {output} (empty is normal in exit-node-only mode)")
    output = run_ssh_command(ssh, 'ip rule show | grep -c "100.64"')
    print(f"  ip rule 100.64 entries: {output}")

    # AdGuard Home
    print("\n🛡️ AdGuard Home:")
    output = run_ssh_command(ssh, 'curl -s -m 3 http://127.0.0.1:3000/control/status 2>/dev/null')
    try:
        agh_data = json.loads(output)
        print(f"  ✅ AGH API: running={agh_data.get('running')}")
    except:
        print(f"  ❌ AGH API: UNREACHABLE")

    # Temperature
    print("\n🌡️ System Health:")
    output = run_ssh_command(ssh, 'echo $(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))')
    temp = int(output)
    status = "✅" if temp < 65 else "⚠️" if temp < 75 else "❌"
    print(f"  {status} Temperature: {temp}°C")

    # RAM
    output = run_ssh_command(ssh, 'free | awk \'NR==2{printf "used=%dMB avail=%dMB", $3/1024, $7/1024}\'')
    print(f"  ℹ️ RAM: {output}")

    # Load Average
    output = run_ssh_command(ssh, 'cat /proc/loadavg')
    print(f"  ℹ️ Load Average: {output}")

    # CPU usage
    output = run_ssh_command(ssh, '''
CPU1=$(cat /proc/stat | grep '^cpu ' | awk '{print $2+$3+$4+$5+$6+$7+$8}')
IDLE1=$(cat /proc/stat | grep '^cpu ' | awk '{print $5}')
sleep 1
CPU2=$(cat /proc/stat | grep '^cpu ' | awk '{print $2+$3+$4+$5+$6+$7+$8}')
IDLE2=$(cat /proc/stat | grep '^cpu ' | awk '{print $5}')
CPU_DIFF=$((CPU2 - CPU1))
IDLE_DIFF=$((IDLE2 - IDLE1))
if [ "$CPU_DIFF" -gt 0 ]; then
    USO_CPU=$((100 * (CPU_DIFF - IDLE_DIFF) / CPU_DIFF))
    echo "${USO_CPU}"
else
    echo "0"
fi
''')
    print(f"  ℹ️ CPU Usage: {output}%")

    # Unbound
    print("\n📡 DNS - Unbound:")
    output = run_ssh_command(ssh, 'pidof unbound > /dev/null 2>&1 && echo "running" || echo "STOPPED"')
    status = "✅" if output == "running" else "❌"
    print(f"  {status} Unbound: {output}")

    output = run_ssh_command(ssh, 'netstat -tlnp | grep 5335 | grep unbound > /dev/null && echo "OK" || echo "FAILED"')
    status = "✅" if output == "OK" else "❌"
    print(f"  {status} Unbound port 5335: {output}")

    # DNS resolution test
    output = run_ssh_command(ssh, 'nslookup google.com 127.0.0.1 2>&1 | grep -q "Address:" && echo "OK" || echo "FAILED"')
    status = "✅" if output == "OK" else "❌"
    print(f"  {status} DNS resolution: {output}")

    # Threat Alert System
    print("\n🛡️ Threat Alert System:")
    output = run_ssh_command(ssh, 'wc -l < /etc/threat-alert/feeds/emerging_c2_ips.txt 2>/dev/null || echo "0"')
    print(f"  ✅ C2 IPs monitored: {output}")

    # Monitor script delay check
    output = run_ssh_command(ssh, 'grep -q "sleep.*rand" /usr/bin/monitor/monitor_sistema.sh && echo "OK" || echo "MISSING"')
    status = "✅" if output == "OK" else "❌"
    print(f"  {status} Monitor delay: {output}")

    # nlbwmon
    print("\n📊 Network Monitoring:")
    output = run_ssh_command(ssh, 'pidof nlbwmon > /dev/null 2>&1 && echo "running" || echo "STOPPED"')
    status = "✅" if output == "running" else "❌"
    print(f"  {status} nlbwmon: {output}")

    # Recent errors
    print("\n⚠️ Recent Errors (last 5):")
    output = run_ssh_command(ssh, 'logread | grep -iE "error|failed|FAIL|crash" | grep -v "tailscaled\\|logread" | tail -5')
    if output:
        for line in output.split('\n'):
            if line.strip():
                print(f"  {line.strip()[:100]}")
    else:
        print("  ✅ No recent errors")

    # WiFi SSIDs
    print("\n📶 WiFi Networks:")
    output = run_ssh_command(ssh, 'uci show wireless | grep ssid')
    for line in output.split('\n'):
        if 'ssid=' in line:
            print(f"  • {line.split('=')[1].replace(chr(39), '')}")

    # WiFi clients
    print("\n👥 WiFi Clients (by SSID):")
    output = run_ssh_command(ssh, 'if [ -f /usr/bin/monitor/wifi_report.sh ]; then /usr/bin/monitor/wifi_report.sh --summary; else echo "wifi_report.sh not found"; fi')
    for line in output.split('\n'):
        if line.strip():
            print(f"  {line}")

    ssh.close()

def check_beryl():
    """Run checks on Beryl"""
    print("\n" + "=" * 60)
    print("🔍 BERYL (GL-MT3000) - 192.168.10.2")
    print("=" * 60)

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect('192.168.10.2', username='root', password='admin', timeout=10)
    except Exception as e:
        print(f"❌ ERROR connecting to Beryl: {e}")
        return

    # Uptime
    output = run_ssh_command(ssh, 'uptime')
    print(f"\n⏱️ Uptime: {output}")

    # RAM
    output = run_ssh_command(ssh, 'free | awk \'NR==2{printf "used=%dMB avail=%dMB", $3/1024, $7/1024}\'')
    print(f"💾 RAM: {output}")

    # Services
    print("\n📋 Services:")
    for svc in ['dnsmasq', 'dropbear']:
        output = run_ssh_command(ssh, f'pidof {svc} > /dev/null 2>&1 && echo "running" || echo "STOPPED"')
        status = "✅" if output == "running" else "❌"
        print(f"  {status} {svc}: {output}")

    # Gateway connectivity
    output = run_ssh_command(ssh, 'ping -c 2 -W 2 192.168.10.1 > /dev/null 2>&1 && echo "OK" || echo "UNREACHABLE"')
    status = "✅" if output == "OK" else "❌"
    print(f"\n🌐 Gateway (192.168.10.1): {status} {output}")

    # WiFi clients
    print("\n👥 WiFi Clients (by SSID):")
    output = run_ssh_command(ssh, 'if [ -f /usr/bin/monitor/wifi_report.sh ]; then /usr/bin/monitor/wifi_report.sh --summary; else echo "wifi_report.sh not found"; fi')
    for line in output.split('\n'):
        if line.strip():
            print(f"  {line}")

    ssh.close()

if __name__ == "__main__":
    print("\n🚀 Starting Router Health Check...")
    print("📅 Date: 2026-04-27 (UTC) | Local: 2026-04-27 (UTC-6)")
    check_flint2()
    check_beryl()
    print("\n" + "=" * 60)
    print("✅ Router Health Check Complete")
    print("=" * 60)
