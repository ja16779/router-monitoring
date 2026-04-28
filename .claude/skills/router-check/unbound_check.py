#!/usr/bin/env python3
"""
Unbound DNS Health Check
Diagnoses Unbound resolver status, configuration, and performance
"""

import paramiko
import sys
import json

ROUTER = {
    "ip": "192.168.10.1",
    "user": "root",
    "pass": "admin"
}

def ssh_exec(ip, user, password, cmd, timeout=15):
    """Execute SSH command and return output"""
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(ip, username=user, password=password, timeout=timeout, banner_timeout=10)
        stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
        output = stdout.read().decode().strip()
        ssh.close()
        return output, None
    except Exception as e:
        return None, str(e)

def check_unbound():
    """Check Unbound DNS resolver health"""
    print("=" * 70)
    print("UNBOUND DNS — HEALTH CHECK")
    print("=" * 70)

    r = ROUTER
    issues = []

    # Check if service is running
    print("\n--- Servicio ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        "pidof unbound > /dev/null 2>&1 && echo 'running' || echo 'STOPPED'")
    if output == "running":
        print(f"   ✅ Unbound: corriendo")
    else:
        print(f"   ❌ Unbound: DETENIDO")
        issues.append(("service", "unbound", "STOPPED"))

    # Check if port 5335 is listening
    print("\n--- Puerto (5335) ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        "ss -tlnp 2>/dev/null | grep -q ':5335' && echo 'OK' || echo 'CLOSED'")
    if output == "OK":
        print(f"   ✅ Puerto 5335: escuchando")
    else:
        print(f"   ⚠️  Puerto 5335: no está abierto")
        issues.append(("port", "5335", "CLOSED"))

    # Test DNS resolution
    print("\n--- Resolución DNS ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        "nslookup google.com 127.0.0.1 2>&1 | grep -q 'Address:' && echo 'OK' || echo 'FAILED'")
    if output == "OK":
        print(f"   ✅ Resuelve google.com correctamente")
    else:
        print(f"   ❌ Resolución de DNS falló")
        issues.append(("dns", "resolution", "FAILED"))

    # Check upstreams configured
    print("\n--- Upstreams Configurados ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        "grep 'forward-addr:' /etc/unbound/unbound-upstream.conf 2>/dev/null | head -5")
    if output:
        for line in output.split('\n'):
            if line.strip():
                addr = line.split(':')[1].strip() if ':' in line else line
                print(f"   ✅ {line.strip()}")
    else:
        print(f"   ⚠️  No se encontraron upstreams")
        issues.append(("config", "upstreams", "NOT_FOUND"))

    # Query statistics
    print("\n--- Estadísticas de Consultas ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        """unbound-control stats_noreset 2>/dev/null | awk '
        /^num.queries=/ { q=$0; gsub(/.*=/, "", q); print "Consultas totales: " q }
        /^num.cachehits=/ { h=$0; gsub(/.*=/, "", h); print "Cache hits: " h }
        /^num.cachemiss=/ { m=$0; gsub(/.*=/, "", m); print "Cache miss: " m }
        /^num.prefetch=/ { p=$0; gsub(/.*=/, "", p); print "Prefetch: " p }
        /^msg.cache.count=/ { c=$0; gsub(/.*=/, "", c); print "Registros en caché: " c }
        /^msg.cache.bytes=/ { b=$0; gsub(/.*=/, "", b); print "Tamaño caché (bytes): " b }
        ' | head -6""")
    if output:
        for line in output.split('\n'):
            if line.strip():
                print(f"   ℹ️  {line.strip()}")
    else:
        print(f"   ⚠️  No se pudieron obtener estadísticas")

    # Average RTT to upstreams
    print("\n--- Latencia a Upstreams ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        """unbound-control dump_infra 2>/dev/null | awk '
        BEGIN { count=0; total=0 }
        /^NAMESERVER/ && NF >= 4 {
            rtt=$4;
            if (rtt ~ /^[0-9]+$/) {
                count++;
                total += rtt
            }
        }
        END {
            if (count > 0) {
                avg = total / count;
                printf "RTT promedio: %.0f ms (%d servidores)\n", avg, count
            }
        }
        """)
    if output:
        print(f"   ℹ️  {output}")
    else:
        print(f"   ℹ️  Sin datos de RTT (primera ejecución)")

    # Recent errors in logs
    print("\n--- Errores Recientes ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        "logread | grep -i unbound | grep -iE 'error|fail|warn' | tail -3")
    if output:
        for line in output.split('\n'):
            if line.strip():
                if 'error' in line.lower() or 'fail' in line.lower():
                    print(f"   ❌ {line}")
                elif 'warn' in line.lower():
                    print(f"   ⚠️  {line}")
    else:
        print(f"   ✅ Sin errores recientes")

    # Cache hit ratio
    print("\n--- Tasa de Cache Hit ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        """unbound-control stats_noreset 2>/dev/null | awk '
        /^num.queries=/ { q=$0; gsub(/.*=/, "", q) }
        /^num.cachehits=/ { h=$0; gsub(/.*=/, "", h) }
        END {
            if (q > 0) {
                pct = (h / q) * 100;
                printf "Cache hits: %.1f%% (%d / %d)\n", pct, h, q
            }
        }
        ' """)
    if output:
        print(f"   ℹ️  {output}")

    # Memory usage
    print("\n--- Uso de Memoria ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        """ps aux | grep 'unbound' | grep -v grep | awk '{
            rss=$6;
            if (rss > 1024) {
                printf "Unbound: %.1f MB\n", rss/1024
            } else {
                printf "Unbound: %d KB\n", rss
            }
        }' """)
    if output:
        print(f"   ℹ️  {output}")

    # Thread count
    print("\n--- Threads Activos ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        """unbound-control stats_noreset 2>/dev/null | grep '^num.queries=' | wc -l
        unbound-control stats_noreset 2>/dev/null | grep '^thread' | wc -l""")
    if output:
        thread_count = output.strip().split('\n')[-1]
        print(f"   ℹ️  {thread_count} threads de query")

    # Uptime
    print("\n--- Uptime del Servicio ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        """unbound-control stats_noreset 2>/dev/null | awk '
        /^time.now=/ { now=$0; gsub(/.*=/, "", now) }
        /^time.boot=/ { boot=$0; gsub(/.*=/, "", boot) }
        END {
            if (boot > 0 && now > boot) {
                uptime = now - boot;
                days = int(uptime / 86400);
                hours = int((uptime % 86400) / 3600);
                printf "Uptime: %d days, %d hours\n", days, hours
            }
        }
        """)
    if output:
        print(f"   ✅ {output}")

    # Configuration file exists
    print("\n--- Configuración ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        "[ -f /etc/unbound/unbound.conf ] && echo 'OK' || echo 'MISSING'")
    if output == "OK":
        print(f"   ✅ /etc/unbound/unbound.conf existe")
    else:
        print(f"   ❌ Archivo de configuración no encontrado")
        issues.append(("config", "main", "MISSING"))

    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        "[ -f /etc/unbound/unbound-upstream.conf ] && echo 'OK' || echo 'MISSING'")
    if output == "OK":
        print(f"   ✅ /etc/unbound/unbound-upstream.conf existe")
    else:
        print(f"   ❌ Archivo de upstreams no encontrado")
        issues.append(("config", "upstreams", "MISSING"))

    # AdGuard Home integration (downstream)
    print("\n--- Integración con AdGuard Home ---")
    output, err = ssh_exec(r["ip"], r["user"], r["pass"],
        "curl -s -m 2 http://127.0.0.1:3000/control/status 2>/dev/null | grep -q '\"running\"' && echo 'OK' || echo 'DOWN'")
    if output == "OK":
        print(f"   ✅ AdGuard Home activo (puerto 3000)")
    else:
        print(f"   ⚠️  AdGuard Home no responde")
        issues.append(("downstream", "adguardhome", "DOWN"))

    # Summary
    print("\n" + "=" * 70)
    print("RESUMEN")
    print("=" * 70)

    if issues:
        print(f"\n⚠️  Se encontraron {len(issues)} problema(s):")
        for category, item, status in issues:
            print(f"   - [{category}] {item}: {status}")
    else:
        print("\n✅ Unbound está funcionando correctamente")

    print("\n" + "=" * 70)

if __name__ == "__main__":
    try:
        import paramiko
    except ImportError:
        print("❌ ERROR: Se requiere el módulo 'paramiko'")
        print("   Instalar con: pip3 install paramiko")
        sys.exit(1)

    check_unbound()
