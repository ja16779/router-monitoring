import paramiko
import json
import time

def ssh_command(ssh, command):
    stdin, stdout, stderr = ssh.exec_command(command)
    output = stdout.read().decode()
    error = stderr.read().decode()
    return output, error

def check_flint2(ssh):
    results = {}
    
    # Services check
    services = ['adguardhome', 'tailscale', 'mwan3', 'dnsmasq', 'mdns-repeater', 'usteer']
    service_status = {}
    for service in services:
        output, _ = ssh_command(ssh, f'pidof {service} > /dev/null 2>&1 && echo "running" || echo "STOPPED"')
        service_status[service] = output.strip()
    results['services'] = service_status
    
    # WireGuard check
    output, _ = ssh_command(ssh, 'ip link show wg0 2>/dev/null | grep -q "UP" && echo "wg0: UP" || echo "wg0: DOWN"')
    results['wireguard'] = output.strip()
    
    # MWAN3 status
    output, _ = ssh_command(ssh, 'mwan3 status 2>&1 | grep -E "online|offline"')
    results['mwan3'] = output.strip()
    
    # Tailscale status
    output, _ = ssh_command(ssh, 'tailscale status --json | python3 -c "import sys,json; d=json.load(sys.stdin); print(\'TS:\', d.get(\'BackendState\'))"')
    results['tailscale'] = output.strip()
    output, _ = ssh_command(ssh, 'ip route show table 52 | wc -l')
    results['tailscale_table52'] = output.strip()
    output, _ = ssh_command(ssh, 'ip rule show | grep -c "100.64"')
    results['tailscale_iprule'] = output.strip()
    
    # AdGuard Home check
    output, _ = ssh_command(ssh, 'curl -s -m 3 http://127.0.0.1:3000/control/status | python3 -c "import sys,json; d=json.load(sys.stdin); print(\'AGH:\', d.get(\'running\'))" 2>/dev/null || echo "AGH: UNREACHABLE"')
    results['adguard_home'] = output.strip()
    
    # Temperature
    output, _ = ssh_command(ssh, 'echo "Temp: $(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))C"')
    results['temperature'] = output.strip()
    
    # RAM
    output, _ = ssh_command(ssh, 'free | awk \'NR==2{printf "RAM: used=%dMB avail=%dMB\\n", $3/1024, $7/1024}\'')
    results['ram'] = output.strip()
    
    # Disk
    output, _ = ssh_command(ssh, 'df -h /overlay | tail -1')
    results['disk'] = output.strip()
    
    # Recent errors
    output, _ = ssh_command(ssh, 'logread | grep -iE "error|failed|FAIL|crash" | grep -v "tailscaled\\|logread" | tail -5')
    results['recent_errors'] = output.strip()
    
    # CPU and Load Average
    output, _ = ssh_command(ssh, 'cat /proc/loadavg')
    results['loadavg'] = output.strip()
    
    # CPU usage calculation
    output, _ = ssh_command(ssh, '''
CPU1=$(cat /proc/stat | grep '^cpu ' | awk '{print $2+$3+$4+$5+$6+$7+$8}')
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
fi
''')
    results['cpu_usage'] = output.strip()
    
    # Monitor script delay check
    output, _ = ssh_command(ssh, 'grep -q \'sleep.*rand\' /usr/bin/monitor/monitor_sistema.sh && echo "Monitor delay: OK" || echo "Monitor delay: MISSING - causes false CPU alerts"')
    results['monitor_delay'] = output.strip()
    
    # Cron congestion check
    output, _ = ssh_command(ssh, 'grep "^0 \\* \\* \\* \\*" /etc/crontabs/root | wc -l')
    results['cron_minute0'] = output.strip()
    
    # WiFi interfaces
    output, _ = ssh_command(ssh, 'iw dev | grep -E "Interface|phy" | grep -E "phy0-ap0|phy1-ap0" || echo "WiFi interfaces: OK"')
    results['wifi'] = output.strip()
    
    return results

def check_beryl(ssh):
    results = {}
    
    # Basic system info
    output, _ = ssh_command(ssh, 'uptime')
    results['uptime'] = output.strip()
    
    # RAM
    output, _ = ssh_command(ssh, 'free | awk \'NR==2{printf "RAM: used=%dMB avail=%dMB\\n", $3/1024, $7/1024}\'')
    results['ram'] = output.strip()
    
    # Services
    services = ['dnsmasq', 'dropbear']
    service_status = {}
    for service in services:
        output, _ = ssh_command(ssh, f'pidof {service} > /dev/null 2>&1 && echo "running" || echo "STOPPED"')
        service_status[service] = output.strip()
    results['services'] = service_status
    
    # Gateway connectivity
    output, _ = ssh_command(ssh, 'ping -c 2 -W 2 192.168.10.1 > /dev/null 2>&1 && echo "Gateway: OK" || echo "Gateway: UNREACHABLE"')
    results['gateway'] = output.strip()
    
    return results

def main():
    print("=== Router Health Check ===")
    print("Connecting to Flint-2 (192.168.10.1)...")
    
    try:
        ssh_flint = paramiko.SSHClient()
        ssh_flint.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh_flint.connect('192.168.10.1', username='root', password='admin', timeout=10)
        
        flint_results = check_flint2(ssh_flint)
        ssh_flint.close()
        
        print("\n=== Flint-2 Results ===")
        for key, value in flint_results.items():
            print(f"{key}: {value}")
        
    except Exception as e:
        print(f"Error connecting to Flint-2: {e}")
    
    print("\nConnecting to Beryl (192.168.10.2)...")
    
    try:
        ssh_beryl = paramiko.SSHClient()
        ssh_beryl.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh_beryl.connect('192.168.10.2', username='root', password='admin', timeout=10)
        
        beryl_results = check_beryl(ssh_beryl)
        ssh_beryl.close()
        
        print("\n=== Beryl Results ===")
        for key, value in beryl_results.items():
            print(f"{key}: {value}")
        
    except Exception as e:
        print(f"Error connecting to Beryl: {e}")

if __name__ == "__main__":
    main()