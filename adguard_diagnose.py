#!/usr/bin/env python3
"""
Diagnose AdGuard Home issue on Flint-2 router
"""

import paramiko
import subprocess

ROUTER_IP = '192.168.10.1'
USERNAME = 'root'
PASSWORD = 'admin'

def main():
    print("=" * 60)
    print("  ADGUARD HOME DIAGNOSTIC")
    print("=" * 60)

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        print(f"\nConnecting to {ROUTER_IP}...")
        ssh.connect(ROUTER_IP, username=USERNAME, password=PASSWORD, timeout=10)
        print("Connected successfully!")

        # Diagnostic commands
        diagnostics = [
            ("Echo test", "echo 'SSH_WORKS'"),
            ("AdGuard init script exists", "ls -la /etc/init.d/adguardhome 2>&1; echo '---EXITCODE:'$?'---'"),
            ("AdGuard binary exists", "ls -la /usr/bin/AdGuardHome 2>&1; ls -la /usr/sbin/AdGuardHome 2>&1"),
            ("Installed packages", "opkg list-installed | grep -i adguard"),
            ("Init script content", "cat /etc/init.d/adguardhome 2>&1 | head -20"),
            ("Port 53 listeners", "netstat -tlnp 2>/dev/null | grep ':53 ' || ss -tlnp 2>/dev/null | grep ':53 '"),
            ("Config file exists", "ls -la /etc/AdGuardHome/AdGuardHome.yaml 2>&1"),
            ("Data directory", "ls -la /mnt/sda1/AdGuardHome/ 2>&1 || ls -la /var/lib/adguardhome/ 2>&1"),
            ("UCI config", "uci show adguardhome 2>&1"),
            ("System log errors", "logread | grep -i adguard | tail -5 2>&1"),
        ]

        for desc, cmd in diagnostics:
            print(f"\n{'='*50}")
            print(f"  {desc}")
            print(f"{'='*50}")
            stdin, stdout, stderr = ssh.exec_command(cmd)
            out = stdout.read().decode().strip()
            err = stderr.read().decode().strip()
            if out:
                print(out)
            if err:
                print(f"STDERR: {err}")

    except Exception as e:
        print(f"ERROR: {e}")
    finally:
        ssh.close()
        print("\n" + "=" * 60)
        print("  DIAGNOSTIC COMPLETE")
        print("=" * 60)

if __name__ == '__main__':
    main()