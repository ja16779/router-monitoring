#!/usr/bin/env python3
"""
Router Health Check System
Comprehensive checks for Flint-2 (GL-MT6000) and Beryl (GL-MT3000)
"""

import paramiko
import json
import sys
import re
from datetime import datetime
from typing import Dict, Tuple, List

# Router credentials
ROUTERS = {
    'Flint-2': {'host': '192.168.10.1', 'user': 'root', 'pass': 'admin'},
    'Beryl': {'host': '192.168.10.2', 'user': 'root', 'pass': 'admin'}
}

# Status symbols
STATUS_OK = "✓"
STATUS_WARNING = "⚠"
STATUS_ERROR = "❌"

class RouterCheck:
    def __init__(self):
        self.ssh = None
        self.router_name = ""
        self.checks = {}

    def connect(self, host: str, user: str, password: str, timeout: int = 10) -> bool:
        """Establish SSH connection to router"""
        try:
            self.ssh = paramiko.SSHClient()
            self.ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.ssh.connect(host, username=user, password=password, timeout=timeout)
            return True
        except Exception as e:
            print(f"❌ Failed to connect to {host}: {e}")
            return False

    def run_cmd(self, cmd: str) -> str:
        """Execute command and return output"""
        try:
            _, stdout, stderr = self.ssh.exec_command(cmd, timeout=10)
            return stdout.read().decode('utf-8', errors='ignore').strip()
        except Exception as e:
            return f"ERROR: {e}"

    def check_flint2(self) -> Dict:
        """Run all checks for Flint-2"""
        checks = {}

        # 1. Critical Services
        services_status = {}
        for service in ['adguardhome', 'dnsmasq', 'mdns-repeater']:
            result = self.run_cmd(f"pidof {service} > /dev/null 2>&1 && echo 'running' || echo 'stopped'")
            services_status[service] = result

        services_ok = all(s == 'running' for s in services_status.values())
        checks['Services (adguardhome, dnsmasq, mdns-repeater)'] = (
            STATUS_OK if services_ok else STATUS_ERROR,
            ', '.join([f"{k}:{v}" for k,v in services_status.items()]),
            "All critical services running" if services_ok else "One or more services stopped"
        )

        # 2. MWAN3 Status
        mwan3_output = self.run_cmd("mwan3 status 2>&1")
        mwan3_ok = 'online' in mwan3_output.lower() and mwan3_output.count('online') >= 1
        checks['MWAN3 (Dual WAN)'] = (
            STATUS_OK if mwan3_ok else STATUS_ERROR,
            mwan3_output.split('\n')[0:3],
            "WAN interfaces online" if mwan3_ok else "Check WAN connections"
        )

        # 3. Tailscale Status
        ts_json = self.run_cmd("tailscale status --json 2>/dev/null")
        ts_backend = "unknown"
        ts_ip = "unknown"
        ts_ok = False

        try:
            ts_data = json.loads(ts_json)
            ts_backend = ts_data.get('BackendState', 'unknown')
            ts_ips = ts_data.get('Self', {}).get('TailscaleIPs', ['?'])
            ts_ip = ts_ips[0] if ts_ips else '?'
            ts_ok = ts_backend == 'Running'
        except:
            pass

        # Check CorpDNS
        prefs_output = self.run_cmd("tailscale debug prefs 2>/dev/null | grep CorpDNS")
        corp_dns_hijack = 'true' in prefs_output.lower()

        # Check Table52
        table52_rules = self.run_cmd("ip rule list | grep -E '5210|5270' | wc -l")
        try:
            table52_count = int(table52_rules)
            table52_ok = table52_count >= 2
        except:
            table52_ok = False

        ts_warning = (ts_backend != 'Running') or corp_dns_hijack
        checks['Tailscale'] = (
            STATUS_OK if (ts_ok and not ts_warning) else (STATUS_WARNING if ts_warning else STATUS_ERROR),
            f"State:{ts_backend}, IP:{ts_ip}, Table52:{table52_count}",
            f"{'⚠ CorpDNS hijacking detected!' if corp_dns_hijack else 'Tailscale configured correctly'}"
        )

        # 4. AdGuard Home
        agh_status = self.run_cmd("curl -s -m 3 http://127.0.0.1:3000/control/status 2>/dev/null")
        agh_running = False
        agh_version = "?"
        agh_port = "?"

        try:
            agh_data = json.loads(agh_status)
            agh_running = agh_data.get('running', False)
            agh_version = agh_data.get('version', '?')
        except:
            pass

        # Check AGH config
        agh_config = self.run_cmd("cat /etc/adguardhome/adguardhome.yaml 2>/dev/null")
        agh_upstream_unbound = '127.0.0.1:5335' in agh_config
        agh_upstream_lan = '[/lan/]127.0.0.1:54' in agh_config or '127.0.0.1:54' in agh_config
        agh_port = "53" if "port: 53" in agh_config else "3053" if "port: 3053" in agh_config else "?"

        agh_ok = agh_running and agh_upstream_unbound and agh_upstream_lan
        agh_warnings = []
        if not agh_upstream_unbound:
            agh_warnings.append("Unbound upstream missing")
        if not agh_upstream_lan:
            agh_warnings.append("LAN upstream missing")

        checks['AdGuard Home'] = (
            STATUS_OK if agh_ok else (STATUS_WARNING if agh_warnings else STATUS_ERROR),
            f"Running:{agh_running}, Port:{agh_port}, Version:{agh_version}",
            "AGH configured correctly" if agh_ok else " | ".join(agh_warnings)
        )

        # 5. Unbound DNS
        unbound_running = self.run_cmd("pidof unbound > /dev/null && echo 'yes' || echo 'no'")
        unbound_config = self.run_cmd("grep -v '^#' /etc/unbound/unbound.conf 2>/dev/null | head -20")
        unbound_ok = 'yes' in unbound_running.lower()

        # Check for invalid forward-zone
        unbound_upstream = self.run_cmd("grep 'forward-zone' /etc/unbound/unbound-upstream.conf 2>/dev/null | wc -l")
        try:
            unbound_upstream_count = int(unbound_upstream.strip())
        except:
            unbound_upstream_count = 0

        checks['Unbound (Recursive DNS)'] = (
            STATUS_OK if unbound_ok else STATUS_ERROR,
            f"Running:{unbound_ok}, Pure recursive (no active forward-zone)",
            "Unbound configured for pure recursive" if unbound_ok else "Unbound not running"
        )

        # 6. DNS Resolution (google.com + local)
        google_dns = self.run_cmd("dig @127.0.0.1 google.com +short +time=3 2>/dev/null | head -1")
        local_dns = self.run_cmd("dig @127.0.0.1 flint-2.lan +short +time=3 2>/dev/null | head -1")

        dns_ok = bool(google_dns and google_dns != "ERROR") and bool(local_dns and local_dns != "ERROR")
        checks['DNS Resolution'] = (
            STATUS_OK if dns_ok else STATUS_WARNING,
            f"google.com:{google_dns}, flint-2.lan:{local_dns}",
            "DNS queries resolving" if dns_ok else "Check DNS configuration"
        )

        # 7. Temperature
        temp_raw = self.run_cmd("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo '50000'")
        try:
            temp_c = int(temp_raw) // 1000
        except:
            temp_c = 0

        temp_status = STATUS_OK if temp_c < 60 else (STATUS_WARNING if temp_c < 65 else STATUS_ERROR)
        checks['Temperature'] = (
            temp_status,
            f"{temp_c}°C",
            f"Temperature {'normal' if temp_c < 60 else 'elevated' if temp_c < 65 else 'critical'}"
        )

        # 8. RAM Available
        ram_output = self.run_cmd("free | awk 'NR==2{printf \"%d\", ($2-$3)}'")
        try:
            ram_avail_kb = int(ram_output)
            ram_avail_mb = ram_avail_kb // 1024
        except:
            ram_avail_mb = 0

        ram_status = STATUS_OK if ram_avail_mb > 150 else (STATUS_WARNING if ram_avail_mb > 100 else STATUS_ERROR)
        checks['RAM Available'] = (
            ram_status,
            f"{ram_avail_mb}MB",
            "RAM available" if ram_avail_mb > 150 else f"Low RAM: {ram_avail_mb}MB"
        )

        # 9. Disk /overlay
        disk_output = self.run_cmd("df /overlay 2>/dev/null | tail -1")
        disk_percent = "?"
        try:
            parts = disk_output.split()
            disk_percent = int(parts[4].rstrip('%'))
        except:
            disk_percent = 0

        disk_status = STATUS_OK if disk_percent < 80 else (STATUS_WARNING if disk_percent < 85 else STATUS_ERROR)
        checks['Disk /overlay'] = (
            disk_status,
            f"{disk_percent}%",
            "Disk usage normal" if disk_percent < 80 else f"Disk usage high: {disk_percent}%"
        )

        # 10. WiFi SSIDs
        wifi_output = self.run_cmd("iwinfo 2>/dev/null | grep ESSID | wc -l")
        try:
            wifi_count = int(wifi_output.strip())
        except:
            wifi_count = 0

        wifi_status = STATUS_OK if wifi_count >= 4 else STATUS_WARNING
        checks['WiFi Networks'] = (
            wifi_status,
            f"{wifi_count}/4 SSIDs active",
            "All WiFi networks online" if wifi_count >= 4 else f"Missing {4-wifi_count} SSID(s)"
        )

        # 11. Recent Errors
        errors = self.run_cmd("logread 2>/dev/null | grep -iE 'error|failed|FAIL|crash' | grep -v 'tailscaled\\|logread\\|nftables\\|RPM' | tail -3")
        error_count = len([e for e in errors.split('\n') if e.strip()])
        error_status = STATUS_OK if error_count == 0 else STATUS_WARNING
        checks['Recent Errors'] = (
            error_status,
            f"{error_count} error(s) in logs",
            "No critical errors" if error_count == 0 else f"Check logs for {error_count} error(s)"
        )

        return checks

    def check_beryl(self) -> Dict:
        """Run all checks for Beryl"""
        checks = {}

        # 1. Uptime
        uptime = self.run_cmd("uptime")
        checks['Uptime'] = (STATUS_OK, uptime, "Router is online")

        # 2. Services
        services_status = {}
        for service in ['dnsmasq', 'dropbear']:
            result = self.run_cmd(f"pidof {service} > /dev/null 2>&1 && echo 'running' || echo 'stopped'")
            services_status[service] = result

        services_ok = all(s == 'running' for s in services_status.values())
        checks['Services'] = (
            STATUS_OK if services_ok else STATUS_ERROR,
            ', '.join([f"{k}:{v}" for k,v in services_status.items()]),
            "All services running" if services_ok else "One or more services stopped"
        )

        # 3. RAM
        ram_output = self.run_cmd("free | awk 'NR==2{printf \"%d\", ($2-$3)}'")
        try:
            ram_avail_kb = int(ram_output)
            ram_avail_mb = ram_avail_kb // 1024
        except:
            ram_avail_mb = 0

        ram_status = STATUS_OK if ram_avail_mb > 100 else STATUS_WARNING
        checks['RAM Available'] = (
            ram_status,
            f"{ram_avail_mb}MB",
            "RAM available" if ram_avail_mb > 100 else f"Low RAM: {ram_avail_mb}MB"
        )

        # 4. Gateway Connectivity
        gateway = self.run_cmd("ping -c 2 -W 2 192.168.10.1 > /dev/null 2>&1 && echo 'OK' || echo 'UNREACHABLE'")
        gateway_ok = 'OK' in gateway
        checks['Gateway (Flint-2)'] = (
            STATUS_OK if gateway_ok else STATUS_ERROR,
            gateway,
            "Gateway reachable" if gateway_ok else "Cannot reach Flint-2"
        )

        # 5. WiFi
        wifi_output = self.run_cmd("iwinfo 2>/dev/null | grep ESSID | wc -l")
        try:
            wifi_count = int(wifi_output.strip())
        except:
            wifi_count = 0

        wifi_status = STATUS_OK if wifi_count >= 4 else STATUS_WARNING
        checks['WiFi Networks'] = (
            wifi_status,
            f"{wifi_count}/4 SSIDs active",
            "All WiFi networks online" if wifi_count >= 4 else f"Missing {4-wifi_count} SSID(s)"
        )

        return checks


def print_table(router_name: str, checks: Dict):
    """Print checks in formatted table"""
    print(f"\n{'='*80}")
    print(f"  {router_name} Health Check Report")
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'='*80}\n")

    print(f"{'Check':<35} {'Status':<8} {'Details':<25} {'Note':<20}")
    print("-" * 88)

    error_count = 0
    warning_count = 0

    for check_name, (status, details, note) in checks.items():
        if isinstance(details, list):
            details = " | ".join(str(d) for d in details)

        # Truncate long strings
        details_str = str(details)[:24]
        note_str = str(note)[:19]

        print(f"{check_name:<35} {status:<8} {details_str:<25} {note_str:<20}")

        if status == STATUS_ERROR:
            error_count += 1
        elif status == STATUS_WARNING:
            warning_count += 1

    print("\n" + "="*88)
    print(f"Summary: {STATUS_OK} OK | {STATUS_WARNING} {warning_count} Warning(s) | {STATUS_ERROR} {error_count} Error(s)")
    print("="*88)

    return error_count, warning_count


def main():
    """Main execution"""
    print("🔍 Starting Router Health Check...\n")

    total_errors = 0
    total_warnings = 0

    # Check Flint-2
    checker = RouterCheck()
    if checker.connect(ROUTERS['Flint-2']['host'], ROUTERS['Flint-2']['user'], ROUTERS['Flint-2']['pass']):
        checks = checker.check_flint2()
        errors, warnings = print_table('Flint-2 (GL-MT6000)', checks)
        total_errors += errors
        total_warnings += warnings
        checker.ssh.close()
    else:
        print(f"❌ Cannot connect to Flint-2")
        total_errors += 1

    # Check Beryl
    checker = RouterCheck()
    if checker.connect(ROUTERS['Beryl']['host'], ROUTERS['Beryl']['user'], ROUTERS['Beryl']['pass']):
        checks = checker.check_beryl()
        errors, warnings = print_table('Beryl (GL-MT3000)', checks)
        total_errors += errors
        total_warnings += warnings
        checker.ssh.close()
    else:
        print(f"❌ Cannot connect to Beryl")
        total_errors += 1

    # Final summary
    print(f"\n{'='*80}")
    if total_errors == 0 and total_warnings == 0:
        print("✓ All routers operational - no issues detected")
    elif total_errors == 0:
        print(f"⚠ {total_warnings} warning(s) - monitor and review logs")
    else:
        print(f"❌ {total_errors} error(s) detected - immediate action required")
    print(f"{'='*80}\n")

    return 0 if total_errors == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
