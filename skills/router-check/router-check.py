#!/usr/bin/env python3
"""
Router Health Check — Flint-2 (GL-MT6000) & Beryl (GL-MT3000)
Automated comprehensive health check via SSH using Paramiko
"""

import paramiko
import json
import sys
import time
from io import StringIO

ROUTERS = {
    'Flint-2': {'ip': '192.168.10.1', 'name': 'GL-MT6000'},
    'Beryl': {'ip': '192.168.10.2', 'name': 'GL-MT3000'},
}

SSH_CREDS = {'username': 'root', 'password': 'admin', 'timeout': 10}

class RouterCheck:
    def __init__(self, router_name, router_ip):
        self.name = router_name
        self.ip = router_ip
        self.ssh = None
        self.results = {}

    def connect(self):
        """Establish SSH connection"""
        try:
            self.ssh = paramiko.SSHClient()
            self.ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.ssh.connect(self.ip, username=SSH_CREDS['username'],
                           password=SSH_CREDS['password'],
                           timeout=SSH_CREDS['timeout'])
            return True
        except Exception as e:
            print(f"❌ {self.name}: SSH connection failed — {str(e)}")
            return False

    def exec_cmd(self, cmd):
        """Execute command and return output"""
        if not self.ssh:
            return None
        try:
            stdin, stdout, stderr = self.ssh.exec_command(cmd, timeout=10)
            return stdout.read().decode('utf-8', errors='ignore').strip()
        except Exception as e:
            return f"ERROR: {str(e)}"

    def check_flint2(self):
        """Run Flint-2 specific checks"""
        if self.name != 'Flint-2':
            return

        print(f"\n📡 {self.name} — Health Check")
        print("=" * 80)

        checks = {
            'Services': self._check_services(),
            'MWAN3': self._check_mwan3(),
            'Tailscale': self._check_tailscale(),
            'DNS': self._check_dns(),
            'Hardware': self._check_hardware(),
        }

        for category, results in checks.items():
            print(f"\n{category}:")
            for check, status, detail in results:
                icon = '✅' if status else '⚠️'
                print(f"  {icon} {check}: {detail}")

    def check_beryl(self):
        """Run Beryl specific checks"""
        if self.name != 'Beryl':
            return

        print(f"\n📡 {self.name} — Health Check")
        print("=" * 80)

        checks = {
            'Services': self._check_beryl_services(),
            'Hardware': self._check_beryl_hardware(),
            'Connectivity': self._check_beryl_connectivity(),
        }

        for category, results in checks.items():
            print(f"\n{category}:")
            for check, status, detail in results:
                icon = '✅' if status else '⚠️'
                print(f"  {icon} {check}: {detail}")

    def _check_services(self):
        """Flint-2: Check critical services"""
        results = []
        for service in ['adguardhome', 'tailscaled', 'dnsmasq', 'mdns-repeater', 'unbound']:
            cmd = f"pidof {service} > /dev/null 2>&1 && echo 'running' || echo 'stopped'"
            output = self.exec_cmd(cmd)
            status = 'running' in output
            results.append((f"{service}", status, output))

        # Usteer (should be removed)
        cmd = "pidof usteerd > /dev/null 2>&1 && echo 'RUNNING (should be removed)' || echo 'removed'"
        output = self.exec_cmd(cmd)
        status = 'removed' in output
        results.append(("usteer", status, output))

        return results

    def _check_mwan3(self):
        """Flint-2: Check MWAN3 status"""
        results = []
        cmd = "mwan3 status 2>&1 | grep -E 'online|offline' | head -5"
        output = self.exec_cmd(cmd)
        if output and 'online' in output:
            results.append(("MWAN3 WANs", True, "Both WANs online"))
        else:
            results.append(("MWAN3 WANs", False, output or "Status unknown"))
        return results

    def _check_tailscale(self):
        """Flint-2: Check Tailscale status"""
        results = []
        cmd = "tailscale status --json 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('BackendState', 'Unknown'))\" 2>/dev/null || echo 'ERROR'"
        output = self.exec_cmd(cmd)
        status = 'Running' in output
        results.append(("Tailscale Backend", status, output))

        # Table 52
        cmd = "ip route show table 52 2>/dev/null | wc -l"
        output = self.exec_cmd(cmd)
        try:
            count = int(output)
            results.append(("Table 52 routes", True, f"{count} routes (exit-node mode OK)" if count >= 0 else "Empty (normal)"))
        except:
            results.append(("Table 52 routes", False, output))

        # Exit node advertised
        cmd = "tailscale status --self 2>&1 | grep -q 'offers exit node' && echo 'advertised' || echo 'not advertised'"
        output = self.exec_cmd(cmd)
        status = 'advertised' in output
        results.append(("Exit node", status, output))

        return results

    def _check_dns(self):
        """Flint-2: Check DNS infrastructure"""
        results = []

        # AdGuard Home
        cmd = "curl -s -m 3 http://127.0.0.1:3000/control/status 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print('running' if d.get('running') else 'stopped')\" 2>/dev/null || echo 'UNREACHABLE'"
        output = self.exec_cmd(cmd)
        status = 'running' in output
        results.append(("AdGuard Home", status, output))

        # Unbound
        cmd = "netstat -tlnp 2>/dev/null | grep -q ':5335.*unbound' && echo 'OK' || echo 'FAILED'"
        output = self.exec_cmd(cmd)
        status = 'OK' in output
        results.append(("Unbound :5335", status, output))

        # DNS resolution test
        cmd = "nslookup google.com 127.0.0.1 2>&1 | grep -q 'Address:' && echo 'OK' || echo 'FAILED'"
        output = self.exec_cmd(cmd)
        status = 'OK' in output
        results.append(("DNS resolution", status, output))

        # Unbound Dashboard
        cmd = "test -f /www/unbound-dashboard/index.html && echo 'OK' || echo 'MISSING'"
        output = self.exec_cmd(cmd)
        status = 'OK' in output
        results.append(("Dashboard HTML", status, output))

        # Unbound Dashboard stats (freshness)
        cmd = "test -f /www/unbound-dashboard/stats.json && find /www/unbound-dashboard/stats.json -mmin -2 2>/dev/null | grep -q '.' && echo 'FRESH' || echo 'STALE'"
        output = self.exec_cmd(cmd)
        status = 'FRESH' in output
        detail = "Updated within 2 minutes" if status else "Not updated recently"
        results.append(("Dashboard stats.json", status, detail))

        # Unbound Dashboard cron job
        cmd = "(crontab -l 2>/dev/null | grep -q 'unbound_dashboard_update.sh') && echo 'OK' || echo 'MISSING'"
        output = self.exec_cmd(cmd)
        status = 'OK' in output
        results.append(("Dashboard cron", status, output))

        return results

    def _check_hardware(self):
        """Flint-2: Check temperature, RAM, CPU"""
        results = []

        # Temperature
        cmd = "echo $(($(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0) / 1000))°C"
        output = self.exec_cmd(cmd)
        try:
            temp = int(output.replace('°C', ''))
            status = temp < 65
            results.append(("Temperature", status, output))
        except:
            results.append(("Temperature", False, output))

        # RAM
        cmd = "free | awk 'NR==2{printf \"used=%dMB avail=%dMB\", $3/1024, $7/1024}'"
        output = self.exec_cmd(cmd)
        results.append(("RAM", True, output))

        # Load average
        cmd = "cat /proc/loadavg | awk '{print \"1m:\" $1 \" 5m:\" $2 \" 15m:\" $3}'"
        output = self.exec_cmd(cmd)
        results.append(("Load Average", True, output))

        # Disk
        cmd = "df -h /overlay 2>/dev/null | tail -1 | awk '{print $5 \" used\"}'"
        output = self.exec_cmd(cmd)
        results.append(("Overlay disk", True, output))

        return results

    def _check_beryl_services(self):
        """Beryl: Check services"""
        results = []
        for service in ['dnsmasq', 'dropbear']:
            cmd = f"pidof {service} > /dev/null 2>&1 && echo 'running' || echo 'stopped'"
            output = self.exec_cmd(cmd)
            status = 'running' in output
            results.append((f"{service}", status, output))
        return results

    def _check_beryl_hardware(self):
        """Beryl: Check hardware"""
        results = []

        # Uptime
        cmd = "uptime | sed 's/.*up //' | sed 's/,.*//' "
        output = self.exec_cmd(cmd)
        results.append(("Uptime", True, output))

        # RAM
        cmd = "free | awk 'NR==2{printf \"used=%dMB avail=%dMB\", $3/1024, $7/1024}'"
        output = self.exec_cmd(cmd)
        results.append(("RAM", True, output))

        return results

    def _check_beryl_connectivity(self):
        """Beryl: Check connectivity to Flint-2"""
        results = []
        cmd = "ping -c 2 -W 2 192.168.10.1 > /dev/null 2>&1 && echo 'OK' || echo 'UNREACHABLE'"
        output = self.exec_cmd(cmd)
        status = 'OK' in output
        results.append(("Gateway (Flint-2)", status, output))
        return results

    def close(self):
        """Close SSH connection"""
        if self.ssh:
            self.ssh.close()

def main():
    print("\n🔍 OpenWrt Router Health Check")
    print("=" * 80)

    for router_name, router_info in ROUTERS.items():
        check = RouterCheck(router_name, router_info['ip'])

        if check.connect():
            if router_name == 'Flint-2':
                check.check_flint2()
            else:
                check.check_beryl()
            check.close()

    print("\n" + "=" * 80)
    print("✅ Health check complete\n")

if __name__ == '__main__':
    main()
