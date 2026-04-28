#!/usr/bin/env python3
"""
Router Health Check Script
Checks Flint-2 and Beryl routers via SSH
"""

import paramiko
import sys

# Router credentials
ROUTERS = {
    "Flint-2": {"ip": "192.168.10.1", "user": "root", "pass": "admin"},
    "Beryl": {"ip": "192.168.10.2", "user": "root", "pass": "admin"}
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

def check_flint2():
    """Check Flint-2 router health"""
    print("=" * 60)
    print("ROUTER CHECK: Flint-2 (GL-MT6000)")
    print("=" * 60)

    r = ROUTERS["Flint-2"]

    # Check basic connectivity
    output, err = ssh_exec(r["ip"], r["user"], r["pass"], "uptime")
    if err:
        print(f"\n❌ ERROR: No se puede conectar a Flint-2: {err}")
        return False

    print(f"\n✅ Conectado a Flint-2 ({r['ip']})")
    print(f"   {output}")

    results = []

    # Check services
    print("\n--- Servicios Críticos ---")
    services_cmd = """
for s in adguardhome tailscaled mwan3 dnsmasq mdns-repeater; do
    if [ "$s" = "mwan3" ]; then
        /etc/init.d/mwan3 status 2>/dev/null | grep -q "running" && echo "$s: running" || echo "$s: STOPPED"
    else
        echo -n "$s: "; pidof $s > /dev/null 2>&1 && echo "running" || echo "STOPPED"
    fi
done
"""
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"], services_cmd)
    for line in output.split('\n'):
        if 'running' in line:
            print(f"   ✅ {line}")
        elif 'STOPPED' in line:
            print(f"   ❌ {line}")
            results.append(('service', line.split(':')[0], 'ERROR'))
        else:
            print(f"   ℹ️  {line}")

    # WireGuard - DESINSTALADO (2026-04-04)
    print("\n--- WireGuard ---")
    print("   ℹ️  Desinstalado (no se verifica)")

    # MWAN3 status
    print("\n--- MWAN3 Status ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "mwan3 status 2>&1 | grep -E 'online|offline|enabled' | head -10")
    if output:
        wan_online = output.count('online')
        wan_offline = output.count('offline')
        for line in output.split('\n'):
            if 'online' in line:
                print(f"   ✅ {line.strip()}")
            elif 'offline' in line:
                print(f"   ⚠️  {line.strip()}")
        if wan_online >= 1:
            print(f"   ✅ {wan_online} WAN(s) online")
        if wan_offline > 0:
            print(f"   ⚠️  {wan_offline} WAN(s) offline")
            results.append(('mwan3', 'wan', f'{wan_offline} offline'))
    else:
        print("   ⚠️  No se pudo obtener estado de MWAN3")

    # Tailscale
    print("\n--- Tailscale ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "tailscale status --json 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print('BackendState:', d.get('BackendState', 'Unknown'))\"")
    if 'Running' in output:
        print(f"   ✅ {output}")
    else:
        print(f"   ⚠️  {output}")
        results.append(('tailscale', 'backend', output))

    # Table 52 routes (puede estar vacía en modo exit-node-only)
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "ip route show table 52 2>/dev/null | wc -l")
    table_routes = int(output.strip()) if output and output.strip().isdigit() else 0
    if table_routes > 0:
        print(f"   ✅ Tabla 52: {table_routes} rutas")
    else:
        print(f"   ℹ️  Tabla 52: vacía (normal en modo exit-node-only si no hay clientes locales)")
        # No marcar como error, es normal en modo exit-node-only

    # ip rule
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "ip rule show | grep -c '100.64'")
    if output and int(output.strip()) > 0:
        print(f"   ✅ ip rule 100.64.0.0/10 presente ({output.strip()} rules)")
    else:
        print(f"   ⚠️  ip rule 100.64.0.0/10 no encontrado")
        results.append(('tailscale', 'iprule', 'missing'))

    # AdGuard Home
    print("\n--- AdGuard Home ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "curl -s -m 3 http://127.0.0.1:3000/control/status 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print('Running:', d.get('running', False))\"")
    if 'True' in output:
        print(f"   ✅ AGH respondiendo - {output}")
    else:
        print(f"   ❌ AGH: {output}")
        results.append(('agh', 'status', 'unreachable'))

    # Temperature
    print("\n--- Temperatura ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "cat /sys/class/thermal/thermal_zone0/temp")
    if output:
        temp_raw = int(output.strip())
        temp_c = temp_raw / 1000
        if temp_c < 60:
            print(f"   ✅ {temp_c:.1f}°C")
        elif temp_c < 65:
            print(f"   ⚠️  {temp_c:.1f}°C (cerca del límite)")
        else:
            print(f"   ❌ {temp_c:.1f}°C (ALTA)")
            results.append(('temp', 'thermal', f'{temp_c:.1f}C'))

    # RAM
    print("\n--- Memoria ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "free | awk 'NR==2{printf \"Used: %dMB, Avail: %dMB\", \$3/1024, \$7/1024}'")
    if output:
        print(f"   ℹ️  {output}")
        # Parse available
        avail = 0
        if 'Avail:' in output:
            try:
                avail_str = output.split('Avail:')[1].split('MB')[0].strip()
                avail = float(avail_str)
            except:
                pass
        if avail < 100:
            print(f"   ❌ RAM disponible baja ({avail:.0f}MB)")
            results.append(('ram', 'available', f'{avail:.0f}MB'))
        elif avail < 150:
            print(f"   ⚠️  RAM disponible baja ({avail:.0f}MB)")

    # Disk
    print("\n--- Almacenamiento ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "df -h /overlay | tail -1")
    if output:
        parts = output.split()
        if len(parts) >= 5:
            use_pct = parts[4].replace('%', '')
            print(f"   ℹ️  {output}")
            if int(use_pct) > 85:
                print(f"   ❌ Uso de disco alto ({use_pct}%)")
                results.append(('disk', 'overlay', f'{use_pct}%'))
            elif int(use_pct) > 80:
                print(f"   ⚠️  Uso de disco elevado ({use_pct}%)")

    # WiFi
    print("\n--- WiFi ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "ip link show | grep -E 'phy[01]-ap0'")
    if output:
        for line in output.split('\n'):
            if 'UP' in line and 'LOWER_UP' in line:
                iface = line.split(':')[1].strip()
                print(f"   ✅ {iface}: activa")
            elif line.strip():
                print(f"   ⚠️  {line}")

    # CPU Usage
    print("\n--- CPU y Carga del Sistema ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "cat /proc/loadavg")
    if output:
        parts = output.split()
        load_1m = float(parts[0])
        load_5m = float(parts[1])
        load_15m = float(parts[2])
        print(f"   ℹ️  Load avg: {load_1m:.2f} (1m), {load_5m:.2f} (5m), {load_15m:.2f} (15m)")
        if load_1m > 3.0:
            print(f"   ⚠️  Carga alta (>3.0)")
            results.append(('cpu', 'load_1m', f'{load_1m:.2f}'))
        elif load_1m > 2.0:
            print(f"   ⚠️  Carga elevada")

    # Calculate CPU usage
    cpu_cmd = """
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
"""
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"], cpu_cmd)
    if output:
        cpu_pct = 0
        try:
            cpu_pct = int(output.replace('CPU: ', '').replace('%', '').strip())
        except:
            pass
        if cpu_pct < 70:
            print(f"   ✅ {output}")
        elif cpu_pct < 80:
            print(f"   ⚠️  {output} (elevado)")
        else:
            print(f"   ⚠️  {output} (alto - verificar procesos)")

    # Check monitor_sistema.sh has random delay
    print("\n--- Script monitor_sistema.sh ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "grep -q 'sleep.*rand' /usr/bin/monitor/monitor_sistema.sh && echo 'OK' || echo 'MISSING'")
    if 'OK' in output:
        print("   ✅ Delay aleatorio presente (evita falsas alertas)")
    else:
        print("   ⚠️  Delay aleatorio FALTANTE - agregar: sleep $(awk 'BEGIN{print int(rand()*30)+5}')")
        results.append(('monitor', 'delay', 'missing'))

    # Check cron congestion at minute 0
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "grep '^0 \\* \\* \\* \\*' /etc/crontabs/root | wc -l")
    if output:
        try:
            cron_at_0 = int(output.strip())
            if cron_at_0 > 10:
                print(f"   ⚠️  {cron_at_0} scripts en minuto 0 (alto riesgo de contención)")
            else:
                print(f"   ✅ {cron_at_0} scripts en minuto 0")
        except:
            pass

    # Recent errors
    print("\n--- Errores Recientes ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "logread | grep -iE 'error|failed|FAIL|crash' | grep -v 'tailscaled|logread' | tail -5")
    if output:
        for line in output.split('\n'):
            if line.strip():
                print(f"   ⚠️  {line}")
    else:
        print("   ✅ No se encontraron errores recientes")

    return results

def check_beryl():
    """Check Beryl router health"""
    print("\n" + "=" * 60)
    print("ROUTER CHECK: Beryl (GL-MT3000)")
    print("=" * 60)

    r = ROUTERS["Beryl"]

    # Check basic connectivity
    output, err = ssh_exec(r["ip"], r["user"], r["pass"], "uptime", timeout=10)
    if err:
        print(f"\n❌ ERROR: No se puede conectar a Beryl: {err}")
        return False

    print(f"\n✅ Conectado a Beryl ({r['ip']})")
    print(f"   {output}")

    results = []

    # RAM
    print("\n--- Memoria ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "free | awk 'NR==2{printf \"Used: %dMB, Avail: %dMB\", \$3/1024, \$7/1024}'")
    if output:
        print(f"   ℹ️  {output}")

    # Services
    print("\n--- Servicios ---")
    services_cmd = """
for s in dnsmasq dropbear; do
    echo -n "$s: "; pidof $s > /dev/null 2>&1 && echo "running" || echo "STOPPED"
done
"""
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"], services_cmd)
    for line in output.split('\n'):
        if 'running' in line:
            print(f"   ✅ {line}")
        elif 'STOPPED' in line:
            print(f"   ❌ {line}")
            results.append(('service', line.split(':')[0], 'ERROR'))

    # Connectivity to gateway
    print("\n--- Conectividad ---")
    output, _ = ssh_exec(r["ip"], r["user"], r["pass"],
        "ping -c 2 -W 2 192.168.10.1 > /dev/null 2>&1 && echo 'Gateway: OK' || echo 'Gateway: UNREACHABLE'")
    if 'OK' in output:
        print(f"   ✅ {output}")
    else:
        print(f"   ❌ {output}")
        results.append(('connectivity', 'gateway', 'unreachable'))

    return results

def main():
    print("\n🔍 INICIANDO HEALTH CHECK DE ROUTERS\n")

    # Check if paramiko is installed
    try:
        import paramiko
    except ImportError:
        print("❌ ERROR: Se requiere el módulo 'paramiko'")
        print("   Instalar con: pip3 install paramiko")
        sys.exit(1)

    flint_results = check_flint2()
    beryl_results = check_beryl()

    # Summary
    print("\n" + "=" * 60)
    print("RESUMEN")
    print("=" * 60)

    all_issues = []
    if isinstance(flint_results, list):
        all_issues.extend([('Flint-2', i) for i in flint_results])
    if isinstance(beryl_results, list):
        all_issues.extend([('Beryl', i) for i in beryl_results])

    if all_issues:
        print(f"\n⚠️  Se encontraron {len(all_issues)} problema(s):")
        for router, issue in all_issues:
            print(f"   - [{router}] {issue[0]}: {issue[1]} = {issue[2]}")
        print("\nRecomendación: Revisar los servicios marcados con ❌ o ⚠️")
    else:
        print("\n✅ Todos los checks completados sin problemas críticos")

    print("\n" + "=" * 60)

if __name__ == "__main__":
    main()
