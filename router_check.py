#!/usr/bin/env python3
"""Router health check script for Flint-2 and Beryl."""

import paramiko
import sys

def run_checks(host, name, commands):
    """Run commands on a router via SSH and return results."""
    print(f"\n{'='*60}")
    print(f"  {name} ({host})")
    print(f"{'='*60}")
    
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(host, username='root', password='admin', timeout=10)
        
        results = {}
        for label, cmd in commands.items():
            try:
                stdin, stdout, stderr = ssh.exec_command(cmd, timeout=15)
                output = stdout.read().decode().strip()
                error = stderr.read().decode().strip()
                results[label] = output if output else (error if error else "No output")
            except Exception as e:
                results[label] = f"ERROR: {str(e)}"
        
        ssh.close()
        return results
    except Exception as e:
        print(f"  ❌ FAILED to connect: {e}")
        return None

def check_flint2():
    """Run all Flint-2 checks."""
    commands = {
        "Services": """for s in adguardhome tailscaled dnsmasq mdns-repeater; do
  echo -n "$s: "; pidof $s > /dev/null 2>&1 && echo "running" || echo "STOPPED"
done""",
        "Unbound": """pidof unbound > /dev/null 2>&1 && echo "Unbound: running" || echo "Unbound: STOPPED"
netstat -tlnp 2>/dev/null | grep 5335 | grep unbound > /dev/null && echo "Unbound port 5335: OK" || echo "Unbound port 5335: FAILED" """,
        "MWAN3": "mwan3 status 2>&1 | grep -E 'online|offline|track'",
        "Tailscale": "tailscale status --json 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print('TS BackendState:', d.get('BackendState'))\" 2>/dev/null || echo 'TS: FAILED'",
        "Tailscale Exit Node": "tailscale status --self 2>&1 | grep -q 'offers exit node' && echo 'Exit node: advertised' || echo 'Exit node: NOT advertised'",
        "Tailscale IP Rule": "ip rule show | grep -c '100.64' 2>/dev/null && echo 'ip rules present' || echo 'ip rules missing'",
        "Forward Rule": "nft list chain inet fw4 forward_tailscale 2>&1 | grep -qE 'eth1|lan1' && echo 'Forward rule (TS→WAN): OK' || echo 'Forward rule (TS→WAN): MISSING'",
        "Masquerade eth1": "nft list chain inet fw4 srcnat 2>&1 | grep -qE 'oifname \"eth1\".*iifname \"tailscale0\"' && echo 'Masquerade (eth1): OK' || echo 'Masquerade (eth1): MISSING'",
        "Masquerade lan1": "nft list chain inet fw4 srcnat 2>&1 | grep -qE 'oifname \"lan1\".*iifname \"tailscale0\"' && echo 'Masquerade (lan1): OK' || echo 'Masquerade (lan1): MISSING'",
        "AdGuard Home": "curl -s -m 3 http://127.0.0.1:3000/control/status 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print('AGH running:', d.get('running'))\" 2>/dev/null || echo 'AGH: UNREACHABLE'",
        "DNS Resolution": "nslookup google.com 127.0.0.1 2>&1 | grep -q 'Address:' && echo 'DNS resolution: OK' || echo 'DNS resolution: FAILED'",
        "Temperature": "echo \"Temp: $(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))C\"",
        "RAM": "free | awk 'NR==2{printf \"RAM: used=%dMB avail=%dMB\\n\", $3/1024, $7/1024}'",
        "Disk": "df -h /overlay | tail -1",
        "Load Average": "cat /proc/loadavg",
        "CPU Usage": """CPU1=$(cat /proc/stat | grep '^cpu ' | awk '{print $2+$3+$4+$5+$6+$7+$8}')
IDLE1=$(cat /proc/stat | grep '^cpu ' | awk '{print $5}')
sleep 1
CPU2=$(cat /proc/stat | grep '^cpu ' | awk '{print $2+$3+$4+$5+$6+$7+$8}')
IDLE2=$(cat /proc/stat | grep '^cpu ' | awk '{print $5}')
CPU_DIFF=$((CPU2 - CPU1))
IDLE_DIFF=$((IDLE2 - IDLE1))
if [ "$CPU_DIFF" -gt 0 ]; then
    USO_CPU=$((100 * (CPU_DIFF - IDLE_DIFF) / CPU_DIFF))
    echo "CPU: ${USO_CPU}%"
else
    echo "CPU: 0%"
fi""",
        "Monitor Delay": "grep -q 'sleep.*rand' /usr/bin/monitor/monitor_sistema.sh && echo 'Monitor delay: OK' || echo 'Monitor delay: MISSING'",
        "Cron Contention": "echo \"Scripts at minute 0: $(grep '^0 \\* \\* \\* \\*' /etc/crontabs/root 2>/dev/null | wc -l)\"",
        "Threat Alert C2 IPs": "wc -l < /etc/threat-alert/feeds/emerging_c2_ips.txt 2>/dev/null || echo '0'",
        "Netifyd DPI": "pidof netifyd > /dev/null 2>&1 && echo 'netifyd: OK' || echo 'netifyd: STOPPED'",
        "Internet Detector": "ps | grep internet-detector | grep -v grep | wc -l",
        "Usteer": "pidof usteerd > /dev/null 2>&1 && echo 'usteer: RUNNING (should be removed)' || echo 'usteer: removed (correct)'",
        "Recent Errors": "logread | grep -iE 'error|failed|FAIL|crash' | grep -v 'tailscaled\\|logread\\|usteer' | tail -5",
        "Unbound Latency": "unbound-control stats 2>/dev/null | grep 'recursion.time.avg' || echo 'unbound-control not available'",
    }
    
    return run_checks("192.168.10.1", "Flint-2 (GL-MT6000)", commands)

def check_beryl():
    """Run all Beryl checks."""
    commands = {
        "Uptime": "uptime",
        "RAM": "free | awk 'NR==2{printf \"RAM: used=%dMB avail=%dMB\\n\", $3/1024, $7/1024}'",
        "Services": """for s in dnsmasq dropbear; do
  echo -n "$s: "; pidof $s > /dev/null 2>&1 && echo "running" || echo "STOPPED"
done""",
        "WiFi": "pidof hostapd > /dev/null 2>&1 && echo 'WiFi: OK' || echo 'WiFi: STOPPED'",
        "Gateway Ping": "ping -c 2 -W 2 192.168.10.1 > /dev/null 2>&1 && echo 'Gateway (Flint-2): OK' || echo 'Gateway (Flint-2): UNREACHABLE'",
    }
    
    return run_checks("192.168.10.2", "Beryl (GL-MT3000)", commands)

def print_results(name, results):
    """Print results in a clean table format."""
    if results is None:
        print(f"\n  ❌ Could not connect to {name}")
        return
    
    print(f"\n  {'Check':<35} {'Status':<30} {'Details'}")
    print(f"  {'-'*35} {'-'*30} {'-'*40}")
    
    for label, output in results.items():
        # Determine status
        output_lower = output.lower()
        if any(x in output_lower for x in ['stopped', 'failed', 'missing', 'unreachable', 'error']):
            status = "❌ ERROR"
        elif any(x in output_lower for x in ['warning', 'high', 'missing delay']):
            status = "⚠️ WARNING"
        else:
            status = "✅ OK"
        
        # Truncate long output
        details = output[:80] + "..." if len(output) > 80 else output
        details = details.replace('\n', ' | ')
        
        print(f"  {label:<35} {status:<30} {details}")

def main():
    print("\n" + "="*60)
    print("  🛡️  ROUTER HEALTH CHECK")
    print("="*60)
    
    # Flint-2
    flint2_results = check_flint2()
    print_results("Flint-2", flint2_results)
    
    # Beryl
    beryl_results = check_beryl()
    print_results("Beryl", beryl_results)
    
    print("\n" + "="*60)
    print("  CHECK COMPLETE")
    print("="*60 + "\n")

if __name__ == "__main__":
    main()
