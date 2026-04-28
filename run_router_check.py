#!/usr/bin/env python3
"""
Router Health Check Script
Checks Flint-2 (GL-MT6000) and Beryl (GL-MT3000) health status
"""

import paramiko
import json
import re
from datetime import datetime

# Router credentials
ROUTERS = {
    "Flint-2": {"ip": "192.168.10.1", "user": "root", "pass": "admin"},
    "Beryl": {"ip": "192.168.10.2", "user": "root", "pass": "admin"}
}

# SSH helper
def ssh_exec(ip, user, password, command, timeout=10):
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(ip, username=user, password=password, timeout=timeout)
        stdin, stdout, stderr = ssh.exec_command(command)
        output = stdout.read().decode().strip()
        error = stderr.read().decode().strip()
        ssh.close()
        return output, error
    except Exception as e:
        return "", str(e)

def check_flint2():
    print("=" * 60)
    print("🔥 FLINT-2 (GL-MT6000) HEALTH CHECK")
    print("=" * 60)
    
    r = ROUTERS["Flint-2"]
    results = []
    
    # Check critical services
    print("\n📋 Critical Services:")
    services = ["adguardhome", "tailscale", "mwan3", "dnsmasq", "mdns-repeater", "usteer"]
    for svc in services:
        cmd = f'pidof {svc} > /dev/null 2>&1 && echo "running" || echo "STOPPED"'
        out, err = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
        status = "✅ running" if "running" in out else "❌ STOPPED"
        print(f"  {svc}: {status}")
        results.append((svc, "running" in out))
    
    # WireGuard check
    print("\n🔐 WireGuard:")
    cmd = 'ip link show wg0 2>/dev/null | grep -q "UP" && echo "UP" || echo "DOWN"'
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    wg_status = "✅ UP" if "UP" in out else "❌ DOWN"
    print(f"  wg0: {wg_status}")
    results.append(("wireguard", "UP" in out))
    
    # MWAN3 status
    print("\n🌐 MWAN3 Status:")
    cmd = 'mwan3 status 2>&1 | grep -E "online|offline"'
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    if out:
        for line in out.split('\n'):
            if 'online' in line:
                print(f"  ✅ {line.strip()}")
            elif 'offline' in line:
                print(f"  ❌ {line.strip()}")
    else:
        print("  ⚠️  Could not determine MWAN3 status")
    
    # Tailscale check
    print("\n🔗 Tailscale:")
    cmd = 'tailscale status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get(\\"BackendState\\", \\"Unknown\\"))"'
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    ts_state = out.strip() if out else "Unknown"
    if ts_state == "Running":
        print(f"  ✅ BackendState: {ts_state}")
    else:
        print(f"  ❌ BackendState: {ts_state}")
    results.append(("tailscale_state", ts_state == "Running"))
    
    # Table 52 check
    cmd = 'ip route show table 52 2>/dev/null | wc -l'
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    try:
        routes = int(out.strip()) if out.strip() else 0
        if routes >= 1:
            print(f"  ✅ Table 52 routes: {routes}")
        else:
            print(f"  ⚠️  Table 52 routes: {routes} (possible MWAN3 conflict)")
    except:
        print(f"  ⚠️  Could not check table 52")
    
    # ip rule check
    cmd = 'ip rule show 2>/dev/null | grep -c "100.64" || echo 0'
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    try:
        rules = int(out.strip()) if out.strip() else 0
        print(f"  ✅ Tailscale ip rules: {rules}")
    except:
        pass
    
    # AdGuard Home check
    print("\n🛡️  AdGuard Home:")
    cmd = 'curl -s -m 3 http://127.0.0.1:3000/control/status 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get(\\"running\\", False))"'
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    agh_running = out.strip() == "True"
    if agh_running:
        print("  ✅ Running and responding")
    else:
        print("  ❌ Not responding or not running")
    results.append(("adguardhome_api", agh_running))
    
    # DoQ upstream check
    cmd = 'grep -c "quic://dns.adguard-dns.com" /etc/AdGuardHome/AdGuardHome.yaml 2>/dev/null || echo 0'
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    try:
        doq = int(out.strip()) if out.strip() else 0
        if doq > 0:
            print(f"  ✅ DoQ upstreams configured")
        else:
            print(f"  ⚠️  DoQ upstreams not found")
    except:
        pass
    
    # Temperature check
    print("\n🌡️  Temperature:")
    cmd = 'echo $(($(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null) / 1000))'
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    try:
        temp = int(out.strip()) if out.strip() else 0
        if temp < 60:
            print(f"  ✅ {temp}°C (OK)")
        elif temp < 65:
            print(f"  ⚠️  {temp}°C (warm)")
        else:
            print(f"  ❌ {temp}°C (HOT!)")
        results.append(("temperature", temp < 65))
    except:
        print(f"  ⚠️  Could not read temperature")
    
    # RAM check
    print("\n💾 Memory:")
    cmd = "free | awk 'NR==2{print $7}'"
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    try:
        avail_kb = int(out.strip()) if out.strip() else 0
        avail_mb = avail_kb / 1024
        if avail_mb > 150:
            print(f"  ✅ Available: {avail_mb:.0f}MB")
        elif avail_mb > 100:
            print(f"  ⚠️  Available: {avail_mb:.0f}MB")
        else:
            print(f"  ❌ Available: {avail_mb:.0f}MB (LOW!)")
        results.append(("ram", avail_mb > 100))
    except:
        print(f"  ⚠️  Could not check RAM")
    
    # Disk check
    print("\n💿 Disk (overlay):")
    cmd = "df -h /overlay 2>/dev/null | tail -1 | awk '{print $5}'"
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    try:
        pct = int(out.strip().replace('%', '')) if out.strip() else 0
        if pct < 80:
            print(f"  ✅ {pct}% used")
        elif pct < 85:
            print(f"  ⚠️  {pct}% used")
        else:
            print(f"  ❌ {pct}% used (CRITICAL!)")
        results.append(("disk", pct < 85))
    except:
        print(f"  ⚠️  Could not check disk")
    
    # WiFi check
    print("\n📡 WiFi Interfaces:")
    for iface in ["phy0-ap0", "phy1-ap0"]:
        cmd = f'ip link show {iface} 2>/dev/null | grep -q "UP" && echo "UP" || echo "DOWN"'
        out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
        wifi_status = "✅ UP" if "UP" in out else "❌ DOWN"
        print(f"  {iface}: {wifi_status}")
    
    # Recent errors
    print("\n📜 Recent Errors (last 5):")
    cmd = 'logread 2>/dev/null | grep -iE "error|failed|FAIL|crash" | grep -v "tailscaled\\|logread" | tail -5'
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    if out:
        for line in out.split('\n')[:5]:
            print(f"  ⚠️  {line.strip()[:80]}")
    else:
        print("  ✅ No recent errors found")
    
    return results

def check_beryl():
    print("\n" + "=" * 60)
    print("💎 BERYL (GL-MT3000) HEALTH CHECK")
    print("=" * 60)
    
    r = ROUTERS["Beryl"]
    results = []
    
    # Check connectivity first
    print("\n📡 Connectivity:")
    cmd = 'ping -c 2 -W 2 192.168.10.1 > /dev/null 2>&1 && echo "OK" || echo "UNREACHABLE"'
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    if "OK" in out:
        print("  ✅ Gateway (192.168.10.1): Reachable")
    else:
        print("  ⚠️  Gateway (192.168.10.1): Unreachable")
    
    # Uptime
    print("\n⏱️  Uptime:")
    cmd = "uptime"
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    if out:
        print(f"  {out.strip()}")
    else:
        print("  ⚠️  Could not get uptime")
    
    # RAM
    print("\n💾 Memory:")
    cmd = "free | awk 'NR==2{print $7}'"
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    try:
        avail_kb = int(out.strip()) if out.strip() else 0
        avail_mb = avail_kb / 1024
        if avail_mb > 100:
            print(f"  ✅ Available: {avail_mb:.0f}MB")
        else:
            print(f"  ⚠️  Available: {avail_mb:.0f}MB")
        results.append(("ram", avail_mb > 50))
    except:
        print(f"  ⚠️  Could not check RAM")
    
    # Services
    print("\n📋 Services:")
    services = ["dnsmasq", "dropbear"]
    for svc in services:
        cmd = f'pidof {svc} > /dev/null 2>&1 && echo "running" || echo "STOPPED"'
        out, err = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
        status = "✅ running" if "running" in out else "❌ STOPPED"
        print(f"  {svc}: {status}")
        results.append((svc, "running" in out))
    
    # WiFi
    print("\n📡 WiFi:")
    cmd = 'iw dev 2>/dev/null | grep "Interface" | wc -l'
    out, _ = ssh_exec(r["ip"], r["user"], r["pass"], cmd)
    try:
        wifi_ifaces = int(out.strip()) if out.strip() else 0
        if wifi_ifaces >= 1:
            print(f"  ✅ {wifi_ifaces} WiFi interface(s) active")
        else:
            print(f"  ⚠️  No WiFi interfaces found")
    except:
        print(f"  ⚠️  Could not check WiFi")
    
    return results

def main():
    print(f"\n🚀 Router Health Check - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # Suppress Paramiko logging
    paramiko.util.log_to_file("/dev/null")
    
    flint_results = check_flint2()
    beryl_results = check_beryl()
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 SUMMARY")
    print("=" * 60)
    
    flint_ok = sum(1 for _, ok in flint_results if ok)
    flint_total = len(flint_results)
    
    beryl_ok = sum(1 for _, ok in beryl_results if ok)
    beryl_total = len(beryl_results)
    
    print(f"\n🔥 Flint-2: {flint_ok}/{flint_total} checks passed")
    print(f"💎 Beryl: {beryl_ok}/{beryl_total} checks passed")
    
    if flint_ok == flint_total and beryl_ok == beryl_total:
        print("\n✅ All systems operational!")
    else:
        print("\n⚠️  Some issues detected. Review above.")
    
    print("")

if __name__ == "__main__":
    main()