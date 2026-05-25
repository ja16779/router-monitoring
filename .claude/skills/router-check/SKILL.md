---
name: router-check
description: >
  Use this skill when the user asks to check the router, review router status,
  router health check, check flint, check beryl, revisar router, estado del router,
  or invokes /router-check. Performs a full health check of the OpenWrt routers
  (Flint-2 and Beryl) via SSH using Python Paramiko and reports any issues.
  Includes backup resilience with USB auto-mount and post-restore automation.
  Telegram notifications sent to group Flint2 notifications with topic prefixes.
  Automatic speedtest validation on WAN recovery. Includes verification of
  Threat Alert System (C2 IP blocking, anomaly detection, real-time threat monitoring),
  Internet Detector WAN monitoring, NextDNS quota tracking, and WiFi Client Connection
  Hotplug Tracker (AP-STA events, real-time Telegram alerts with device info).
version: 1.20.0
disable-model-invocation: false
---

# Router Check Skill

Performs a comprehensive health check of the home network routers and reports any issues.

## Network Topology

| Router | Access IP | Tailscale IP | Credentials |
|--------|-----------|--------------|-------------|
| Flint-2 (GL-MT6000) | 192.168.10.1 or 192.168.8.1 | 100.126.168.103 | root/admin |
| Beryl (GL-MT3000) | 192.168.10.2 | — | root/admin |

- SSH via Python Paramiko (password auth: root/admin)
- Primary access: 192.168.10.1 (más estable) o 192.168.8.1

## What to Check

### Flint-2
1. **Servicios críticos**: adguardhome, tailscaled, mwan3, dnsmasq, mdns-repeater (unbound activo, usteer desinstalado 2026-04-24)
2. **WiFi**: 5 SSIDs activas (2 de 2.4GHz, 2 de 5GHz, 1 IoT) — nueva SSID 2.4GHz agregada 2026-04-24
3. **MWAN3**: ambas WANs online (wan + secondwan)
4. **Tailscale**: BackendState=Running, ip rule 100.64.0.0/10, exit node advertiseded (0.0.0.0/0)
   - **Nota**: tabla 52 puede estar vacía en modo exit-node-only (normal si no hay rutas locales)
5. **Tailscale exit node**: Forward rule (tailscale0 → eth1/lan1), masquerade rules activas
6. **WireGuard**: DESINSTALADO (ya no se chequea)
7. **DNS**: AdGuardHome:53 → Unbound:5335 (recursive + auth-zones ICANN), fallback NextDNS DoT (29e346)
8. **AdGuard Home**: respondiendo en puerto 53 (DNS) y 3000 (web UI), upstream Unbound:5335, **IPv4 only** (127.0.0.1)
   - Si Unbound cae → fallback automático a NextDNS DoT (upstream_timeout: 6s)
9. **Temperatura**: menor a 65°C (valor raw < 65000)
10. **RAM**: disponible > 100MB
11. **CPU**: verificar carga del sistema (load average) y uso de CPU
12. **Errores en logs**: tailscale open-conn-track, MWAN3 failures, firewall drops, unbound errors
13. **Scripts de monitoreo**: verificar que monitor_sistema.sh tenga delay aleatorio (evita falsos positivos de CPU >90%)
14. **Speedtest horario**: speedtest_monitor.sh ejecutándose cada hora (cron líneas 7 y 17), umbrales 280 Mbps (Telmex/80%), 168 Mbps (Megacable/80%)
15. **WiFi Hotplug Tracker**: Sistema event-driven captura AP-STA-CONNECTED/DISCONNECTED eventos
    - **Procesos**: 5 instancias de `hostapd_cli -a /etc/hotplug.d/wifi/50-client-tracker` (uno per interfaz phy*-ap*)
    - **Handler**: `/etc/hotplug.d/wifi/50-client-tracker` (script de 89 líneas) — resuelve hostname, SSID, IP, MAC, bitrate
    - **Telegram**: Alertas instantáneas con formato HTML (hostname, SSID, IP, MAC, banda, bitrate/signal)
    - **Log**: `/var/log/wifi_client_tracker.log` — eventos con timestamps
    - **Persistencia**: Agregado a sysupgrade.conf para preservar post-upgrade
    - **Status**: ✅ PRODUCTIVO — ambos eventos (CONNECT + DISCONNECT) capturados

### Beryl
1. **Servicios**: dnsmasq, dropbear, wifi
2. **Uptime y RAM**
3. **Conectividad**: ping a 192.168.10.1
4. **WiFi Hotplug Tracker**: Sistema event-driven identical a Flint-2
    - **Procesos**: 5 instancias de `hostapd_cli -a /etc/hotplug.d/wifi/50-client-tracker` (phy0-ap0, phy0-ap2, phy1-ap0, wlan0-1, wlan1-1)
    - **Interfaces**: 5 APs activos (2.4GHz: phy0-ap0, phy0-ap2, wlan0-1 | 5GHz: phy1-ap0, wlan1-1)
    - **SSIDs monitoreadas**: 4 únicas (Mega_2.4G_A2DF, AXTEL XTREMO×2, IOT, Mega_5G_A2DF)
    - **Telegram Token**: REDACTED_BOT_TOKEN (bot de Beryl)
    - **Status**: ✅ OPERATIVO — Ambos eventos (CONNECT + DISCONNECT) capturados

## How to Execute

Use Python Paramiko to SSH into each router and run checks. Example connection:

```python
import paramiko
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('192.168.10.1', username='root', password='admin', timeout=10)
stdin, stdout, stderr = ssh.exec_command('command')
output = stdout.read().decode()
```

## Commands to Run on Flint-2

```sh
# Services
for s in adguardhome tailscaled dnsmasq mdns-repeater; do
  echo -n "$s: "; pidof $s > /dev/null 2>&1 && echo "running" || echo "STOPPED"
done

# Usteer status (desinstalado 2026-04-24)
echo -n "usteer: "; pidof usteerd > /dev/null 2>&1 && echo "RUNNING (should be removed)" || echo "removed"

# MWAN3
mwan3 status 2>&1 | grep -E "online|offline"

# Tailscale
tailscale status --json | python3 -c "import sys,json; d=json.load(sys.stdin); print('TS:', d.get('BackendState'))"
ip route show table 52 | wc -l
ip rule show | grep -c "100.64"

# AdGuard Home (puerto 3000 para API/GUI, puerto 53 para DNS)
curl -s -m 3 http://127.0.0.1:3000/control/status 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print('AGH:', d.get('running'))" 2>/dev/null || echo "AGH: UNREACHABLE"

# Temperature
echo "Temp: $(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))C"

# RAM
free | awk 'NR==2{printf "RAM: used=%dMB avail=%dMB\n", $3/1024, $7/1024}'

# Disk (overlay)
df -h /overlay | tail -1

# Recent errors
logread | grep -iE "error|failed|FAIL|crash" | grep -v "tailscaled\|logread" | tail -5

# CPU and Load Average
cat /proc/loadavg

# CPU calculation (correct method)
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

# Check monitor_sistema.sh has random delay
grep -q 'sleep.*rand' /usr/bin/monitor/monitor_sistema.sh && echo "Monitor delay: OK" || echo "Monitor delay: MISSING - causes false CPU alerts"

# Check for cron congestion at minute 0
grep "^0 \* \* \* \*" /etc/crontabs/root | wc -l
echo "Scripts running at minute 0 (high contention risk)"

# DNS - Unbound
pidof unbound > /dev/null 2>&1 && echo "Unbound: running" || echo "Unbound: STOPPED"
netstat -tlnp | grep 5335 | grep unbound > /dev/null && echo "Unbound port 5335: OK" || echo "Unbound port 5335: FAILED"

# DNS resolution test (without Tailscale dependency)
nslookup google.com 127.0.0.1 2>&1 | grep -q "Address:" && echo "DNS resolution: OK" || echo "DNS resolution: FAILED"

# Unbound upstreams (check for static DNS)
grep -c "forward-addr:" /etc/unbound/unbound-upstream.conf 2>/dev/null || echo "Unbound upstreams: CHECK MANUALLY"

# Tailscale exit node
tailscale status --self 2>&1 | grep -q "offers exit node" && echo "Exit node: advertised" || echo "Exit node: NOT advertised"

# Firewall forward rule for exit node (check for eth1 and lan1)
nft list chain inet fw4 forward_tailscale 2>&1 | grep -qE "eth1|lan1" && echo "Forward rule (TS→WAN): OK" || echo "Forward rule (TS→WAN): MISSING or INCORRECT (should have eth1, not pppoe-wan)"

# Masquerade rules for exit node
nft list chain inet fw4 srcnat 2>&1 | grep -qE "oifname \"eth1\".*iifname \"tailscale0\"" && echo "Masquerade rule (eth1): OK" || echo "Masquerade rule (eth1): MISSING"
nft list chain inet fw4 srcnat 2>&1 | grep -qE "oifname \"lan1\".*iifname \"tailscale0\"" && echo "Masquerade rule (lan1): OK" || echo "Masquerade rule (lan1): MISSING"

# WiFi Hotplug Tracker — AP-STA event monitoring
echo "--- WiFi Hotplug Tracker ---"
ps w | grep "hostapd_cli -a /etc/hotplug.d/wifi/50-client-tracker" | grep -v grep | wc -l | grep -q "5" && echo "Hostapd_cli processes: OK (5 running)" || echo "Hostapd_cli processes: CHECK - should be 5"
[ -f /etc/hotplug.d/wifi/50-client-tracker ] && echo "Handler installed: OK" || echo "Handler installed: MISSING"
[ -f /var/log/wifi_client_tracker.log ] && echo "Log file exists: OK" || echo "Log file exists: MISSING"
tail -3 /var/log/wifi_client_tracker.log 2>/dev/null | grep -q "Event:" && echo "Recent events: OK" || echo "Recent events: NONE"
grep -q "/etc/hotplug.d/wifi/50-client-tracker" /etc/sysupgrade.conf && echo "Persistence: OK" || echo "Persistence: NOT CONFIGURED"
```

## Commands to Run on Beryl

```sh
uptime
free | awk 'NR==2{printf "RAM: used=%dMB avail=%dMB\n", $3/1024, $7/1024}'
for s in dnsmasq dropbear; do
  echo -n "$s: "; pidof $s > /dev/null 2>&1 && echo "running" || echo "STOPPED"
done
ping -c 2 -W 2 192.168.10.1 > /dev/null 2>&1 && echo "Gateway: OK" || echo "Gateway: UNREACHABLE"
```

## Alert Thresholds

| Check | OK | Warning |
|-------|----|---------|
| Temperature | < 60°C | > 65°C |
| RAM available | > 150MB | < 100MB |
| Overlay disk | < 80% | > 85% |
| Load Average (1m) | < 2.0 | > 3.0 |
| CPU usage (spikes) | < 70% | > 80% sustained |
| Tailscale BackendState | Running | Anything else |
| Table 52 routes | Any (vacía es normal en exit-node-only) | N/A |
| Services | running | stopped |
| Monitor script delay | Has `sleep $(rand...)` | Missing delay |

## Timezone

The router clocks run in **UTC**. The user is in **UTC-6 (Mexico City / CST)**. When referencing timestamps from querylog or logread, always convert to local time or note the UTC offset explicitly to avoid confusion.

## Tailscale Exit Node (nuevo, 2026-04-05)

### Configuración activa
- **Modo**: Router configurado como exit node (anuncia 0.0.0.0/0)
- **Clientes**: iPhone puede seleccionar flint-2 como exit node para salida a internet
- **Networking**: Tráfico desde iPhone entra por `tailscale0`, sale por `wan` (DHCP, eth1) o `lan1`

### Reglas requeridas para funcionar
1. **Forward rule** (permitir forwarding tailscale0 → WAN):
   ```
   nft add rule inet fw4 forward_tailscale "oifname { \"eth1\", \"lan1\" } counter accept"
   ```
   - `eth1` = WAN primaria (DHCP desde 2026-04-13)
   - `lan1` = WAN secundaria (pppoe-wan → lan1)

2. **Masquerade rules** (traducir IPs para salida a internet):
   ```
   nft add rule inet fw4 srcnat oifname "eth1" iifname "tailscale0" meta nfproto ipv4 masquerade
   nft add rule inet fw4 srcnat oifname "lan1" iifname "tailscale0" meta nfproto ipv4 masquerade
   ```

3. **Persistencia**: Reglas guardadas en `/etc/firewall.user` (se aplican en firewall.start)
   - ⚠️ Fix (2026-04-17): Reglas originales usaban `pppoe-wan` (no existe), actualizado a `eth1`

### Verificación
```sh
# Exit node advertised?
tailscale status | grep "offers exit node"

# Forward rules exist?
nft list chain inet fw4 forward_tailscale | grep -E "eth1|lan1"

# Masquerade rules exist?
nft list chain inet fw4 srcnat | grep -A 2 "tailscale0" | grep -E "eth1|lan1"
```

### Troubleshooting
- **iPhone no ve exit node**: Reiniciar `tailscaled` para reavertir netmap
- **Internet no funciona en iPhone**: Verificar forward rules usando `nft list chain inet fw4 forward_tailscale | grep eth1` (debe estar activa)
  - ⚠️ **Nota importante**: Las reglas deben usar `eth1` (WAN primaria DHCP), NO `pppoe-wan` (que no existe desde 2026-04-13). Revisar `/etc/firewall.user` líneas 3-5.
- **Conexión lenta**: Verificar UDP GRO warning, considerar `ethtool -K eth1 rx-udp-gro-forwarding on`
- **Tabla 52 vacía pero Tailscale funciona**: Esto es NORMAL en modo exit-node-only. La tabla 52 se usa para rutas internas de Tailscale. Si no hay clientes locales usando Tailscale (solo el router actúa como exit node), la tabla puede estar vacía. Verificar con `tailscale status` que el router está conectado y en modo exit node.
- **ip rule presente pero tabla 52 vacía**: Verificar que MWAN3 no está tomando tabla 52 (revisar `/etc/config/mwan3`). Usar `ip rule show table 1` y `ip rule show table 2` para confirmar que MWAN3 usa otras tablas.

## DNS — Arquitectura Final (actualizado 2026-04-17)

### Arquitectura actual
```
Clientes LAN → DHCP option 6: 192.168.10.1
    ↓
AdGuardHome:53 (filtrado + logs, IPv4 only)
    ↓ upstream_timeout: 6s
Unbound:5335 (recursive resolver + auth-zones ICANN)
    ├── Cache local (8m msg + 16m rrset = 24MB) → 63% hit rate
    ├── Auth-zones: root.zone (2.1MB), arpa.zone, in-addr.arpa.zone
    └── Fallback: recursión a root servers
    ↓ (cache miss ~37%)
tls://29e346.dns.nextdns.io (NextDNS DoT, perfil 29e346)
    ↓
Fallback AGH: 45.90.28.0, 45.90.30.0 (NextDNS anycast si Unbound cae)

dnsmasq → solo DHCP (port=0, sin DNS)
IoT VLAN (br-lan.8) → DHCP option 6: 45.90.28.0, 45.90.30.0 (NextDNS Anycast directo, bypasa AGH)
```

### Archivos de configuración
- `/etc/adguardhome/adguardhome.yaml`: DNS puerto 53, upstream Unbound:5335, fallback NextDNS DoT
- `/etc/config/unbound`: UCI config (listen_port=5335, validator_ntp=0, auth-zones habilitadas)
- `/var/lib/unbound/unbound.conf`: Config generada por UCI
- `/var/lib/unbound/unbound_srv.conf`: Overrides (num-threads=4, prefetch, cache sizes, module-config sin validator)
- `/etc/config/dhcp`: dnsmasq DHCP only (port=0), option 6 LAN=192.168.10.1

### Parámetros clave de Unbound
- `num-threads: 4` (override UCI que genera 2) - **CRÍTICO**: afecta latencia
- `cache-min-ttl: 120` / `cache-max-ttl: 72000` (20 horas)
- `ratelimit: 1000` / `ip-ratelimit: 500`
- `module-config: "respip iterator"` (sin validator — **CRÍTICO para latencia baja**)
  - ⚠️ **Si valida aparece**: ejecutar `/usr/local/bin/unbound_validator_fix.sh`
- `validator_ntp: 0` — **CRÍTICO**: permite que se generen las auth-zones en unbound.conf

### Latencia DNS Actual (2026-04-24)
```
LATENCIA REAL (verificada):
thread0.recursion.time.avg: 0.332ms
thread1.recursion.time.avg: 0.238ms
thread2.recursion.time.avg: 0.306ms
thread3.recursion.time.avg: 0.336ms
TOTAL: 0.328ms ← EXCELENTE (vs 134ms inicial)

Comando de verificación:
unbound-control stats_noreset | grep "recursion.time"
```

⚠️ **NOTA IMPORTANTE - AdGuardHome Dashboard Bug:**
- AdGuardHome muestra "Average upstream response time" FALSO (10x más alto)
- Es bug conocido #6818 - dashboard muestra 400ms+ pero latencia real es 0.3ms
- IGNORAR la métrica del dashboard - usar comando anterior para verificar latencia real

### Auth-zones ICANN (descargan vía AXFR)
```
lax.xfr.dns.icann.org, iad.xfr.dns.icann.org
  └── root.zone     (2.1MB - zona raíz)
  └── arpa.zone     (35.4KB)
  └── in-addr.arpa.zone (215.8KB)
```

### Watchdog Unbound
```
# /etc/crontabs/root — cada minuto (ventana máx 1 min si Unbound cae)
* * * * *  [ -z "$(pidof unbound)" ] && /etc/init.d/unbound restart
```

### Verificación
```sh
# ¿Unbound corriendo?
pidof unbound && echo "OK" || echo "STOPPED"
ss -tlnp | grep ':5335'

# ¿Auth-zones descargadas?
ls -lh /var/lib/unbound/*.zone

# ¿Hit rate?
unbound-control stats_noreset | grep -E "cachehits|cachemiss"

# ¿AGH upstream activo?
curl -s http://127.0.0.1:3000/control/status | grep running

# ¿DNS resuelve?
nslookup google.com 127.0.0.1
```

### Troubleshooting
- **Unbound no arranca**: Verificar `validator_ntp='0'` en `/etc/config/unbound`
- **Auth-zones no aparecen en unbound.conf**: `validator_ntp` debe ser 0, no 1
- **DNS lento (>100ms)**: 
  - Verificar que validator NO está en module-config: `grep "validator" /var/lib/unbound/unbound.conf`
  - Si aparece: ejecutar `/usr/local/bin/unbound_validator_fix.sh`
  - Verificar num-threads=4: `grep "num-threads" /var/lib/unbound/unbound.conf`
- **AdGuardHome no conecta a Unbound**: 
  - ⚠️ ujail está bloqueando - verificar `/etc/init.d/adguardhome` no tiene `procd_add_jail`
  - Desabilitar ujail comentando líneas `procd_add_jail*` en script
- **AGH muestra 400ms+ en dashboard pero latencia real es 0.3ms**: Es bug #6818, ignorar métrica
- **SERVFAIL frecuentes**: Ocurría con `module-config: "respip validator iterator"`. Solución: cambiar a `"respip iterator"`

### DNS Performance Checklist
```bash
# Ejecutar cuando DNS se vuelva lento:

# 1. ¿Validator está activo?
grep "module-config" /var/lib/unbound/unbound.conf
# Debe ser: module-config: "respip iterator" (SIN validator)

# 2. ¿Num-threads es 4?
grep "num-threads" /var/lib/unbound/unbound.conf
# Debe ser: num-threads: 4

# 3. ¿AGH conecta a Unbound?
QUERIES_BEFORE=$(unbound-control stats_noreset | grep "^total.num.queries=" | awk -F= '{print $2}')
nslookup test.example.com 127.0.0.1:53 > /dev/null 2>&1
QUERIES_AFTER=$(unbound-control stats_noreset | grep "^total.num.queries=" | awk -F= '{print $2}')
[ $QUERIES_AFTER -gt $QUERIES_BEFORE ] && echo "✓ AGH conecta" || echo "✗ ujail bloqueando"

# 4. ¿Cuál es la latencia real?
unbound-control stats_noreset | grep "total.recursion.time.avg="
# Esperar < 1ms para latencia buena
```

## NextDNS Critical Domains Synchronization (nuevo, 2026-04-24)

### Sincronización Automática al Whitelist

**Script**: `/usr/local/bin/nextdns_sync.sh`

### Dominios Críticos (Agregados 2026-04-24 13:37 UTC)

| Dominio | Dispositivo | Querys Bloqueadas | Estado |
|---------|-------------|-------------------|--------|
| **a.root-servers.net** | Sistema DNS global | 1,246 | ✅ Agregado |
| **m2.tuyacn.com** | LGE_AC2_open (AC Tuya) | 2,332 | ✅ Agregado |
| **api.amazonalexa.com** | amazon-630ca9591 | N/A | ✅ Agregado |

### Función del Script

```bash
# Ubicación
/usr/local/bin/nextdns_sync.sh

# Ejecuta manualmente
ssh root@192.168.10.1 /usr/local/bin/nextdns_sync.sh

# Cron automático (02:00 AM UTC diarios)
0 2 * * * /usr/local/bin/nextdns_sync.sh >> /var/log/nextdns_sync.log 2>&1
```

### Configuración

```bash
# API Key
API_KEY="b537a050b3e26cf136a99bb7907f756524ebd8ab"

# NextDNS Profile ID (nuevo)
PROFILE_ID="29e346"

# Endpoint de API
https://api.nextdns.io/profiles/29e346/allowlist

# Log de ejecución
/var/log/nextdns_sync.log
```

### Dominios Sincronizados

```
a.root-servers.net              ✅ Agregado
m2.tuyacn.com                   ✅ Agregado
api.amazonalexa.com             ✅ Agregado
nrdp.logs.netflix.com           ⚠️ Ya existente
api.us-east-1.aiv-delivery.net  ✅ Agregado
logs.netflix.com                ✅ Agregado
mx.info.lgsmartad.com           ⚠️ Ya existente

Resultado: 5 nuevos + 2 existentes, 0 errores
```

### Verificación

```bash
# Ver último resultado
ssh root@192.168.10.1 "tail -10 /var/log/nextdns_sync.log"

# Verificar que dominios resuelven
ssh root@192.168.10.1 "nslookup a.root-servers.net 127.0.0.1"
ssh root@192.168.10.1 "nslookup m2.tuyacn.com 127.0.0.1"
ssh root@192.168.10.1 "nslookup api.amazonalexa.com 127.0.0.1"
```

### Impacto

- **DNS Root**: 1,246 queries bloqueadas → ahora resuelve normal
- **Tuya IoT**: AC unit (LGE_AC2_open) recupera conectividad MQTT
- **Amazon Alexa**: Dispositivo amazon-630ca9591 recupera conectividad API
- **Netflix**: Servicios de streaming (logs, delivery API) funcionan normalmente

## NextDNS Analytics — Evaluación de Dominios Bloqueados (nuevo, 2026-04-24)

### Propósito

Sistema para revisar periódicamente qué dominios está bloqueando NextDNS, evaluar impacto en dispositivos, y decidir si desbloquear o mantener bloqueados.

### 1. Ver Dominios Bloqueados

```bash
# Obtener lista de dominios bloqueados en NextDNS (TOP 20)
ssh root@192.168.10.1 << 'EOF'
PROFILE="29e346"
API_KEY="b537a050b3e26cf136a99bb7907f756524ebd8ab"

curl -s "https://api.nextdns.io/profiles/$PROFILE/analytics/domains?status=blocked&limit=20" \
  -H "X-Api-Key: $API_KEY" | jq '.' | head -50
EOF
```

### 2. Evaluación de Impacto

**Criterios para determinar criticidad:**

| Criticidad | Señales | Acción |
|-----------|---------|--------|
| 🔴 **CRÍTICA** | >100 queries, dispositivo no funciona (Tuya, Alexa, DNS root) | ✅ DESBLOQUEAR inmediatamente |
| 🟡 **MEDIA** | 10-100 queries, servicio degradado (streaming, actualizaciones) | ⚠️ EVALUAR — desbloquear si afecta uso frecuente |
| 🟢 **BAJA** | <10 queries, telemetría o tracking (ads, analytics) | ✅ MANTENER BLOQUEADO |

### 3. Clasificación de Dominios

```
🔴 CRÍTICA → DNS infrastructure, IoT MQTT, VoIP, autenticación
🟡 MEDIA → Streaming (Netflix, YouTube), software updates, cloud storage
🟢 BAJA → Publicidad, analytics, telemetría, social media tracking
```

### 4. Proceso de Decisión

**Preguntas clave antes de desbloquear:**

1. ¿Afecta a un dispositivo crítico en la red? (Tuya, Alexa, LG AC, etc.)
2. ¿Cuántas queries por día? (>50 = probablemente crítico)
3. ¿Es infraestructura o servicio? (DNS, MQTT, API crítica)
4. ¿Hay alternativa segura? (proxy, VPN, diferentes servidor)

**Ejemplos de decisiones:**

| Dominio | Queries | Dispositivo | Decisión | Razón |
|---------|---------|-------------|----------|-------|
| a.root-servers.net | 1,246/día | Sistema DNS | 🟢 DESBLOQUEAR | Infraestructura crítica |
| m2.tuyacn.com | 2,332/día | LGE_AC2_open | 🟢 DESBLOQUEAR | IoT MQTT crítica |
| api.amazonalexa.com | N/A | amazon-630ca9591 | 🟢 DESBLOQUEAR | VoIP/Smart Home crítica |
| logs.netflix.com | 100/día | LG TV | 🟡 DESBLOQUEAR | Streaming, uso frecuente |
| mx.info.lgsmartad.com | 50/día | LG TV | 🟢 DESBLOQUEAR | Funcionamiento TV |
| ads.google.com | 200/día | Múltiples | 🟢 MANTENER | Publicidad, no esencial |
| analytics.google.com | 300/día | Navegadores | 🟢 MANTENER | Telemetría, no esencial |

### 5. Agregar al Whitelist Automáticamente

```bash
# Opción A: Usar script existente
# Editar /usr/local/bin/nextdns_sync.sh y agregar dominio a array DOMAINS:

ssh root@192.168.10.1 << 'EOF'
# Editar el archivo
sed -i '/DOMAINS=(/a\    "nuevo.dominio.com"' /usr/local/bin/nextdns_sync.sh

# Ejecutar inmediatamente
/usr/local/bin/nextdns_sync.sh
EOF

# Opción B: Agregar manual vía curl
ssh root@192.168.10.1 << 'EOF'
PROFILE="29e346"
API_KEY="b537a050b3e26cf136a99bb7907f756524ebd8ab"

curl -s -X POST "https://api.nextdns.io/profiles/$PROFILE/allowlist" \
  -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"id": "nuevo.dominio.com"}' | jq '.'
EOF
```

### 6. Monitoreo Posterior

```bash
# Después de desbloquear, verificar:

# 1. Dominio se agrega al whitelist (sin errores)
ssh root@192.168.10.1 "tail -5 /var/log/nextdns_sync.log"

# 2. Dominio se resuelve correctamente
ssh root@192.168.10.1 "nslookup nuevo.dominio.com 127.0.0.1"

# 3. Dispositivo recupera funcionalidad (Telegram alert o verificación manual)
# Ejemplo: LG AC vuelve a conectarse a Tuya, Alexa responde a comandos
```

### 7. Revisión Periódica

**Cron automático (opcional):**
```bash
# Crear dashboard diario (08:00 AM)
0 8 * * * /usr/local/bin/nextdns_analytics.sh --report
```

**Script `/usr/local/bin/nextdns_analytics.sh`:**
```bash
#!/bin/bash
PROFILE="29e346"
API_KEY="b537a050b3e26cf136a99bb7907f756524ebd8ab"

echo "🔍 NextDNS Blocked Domains Report"
echo "=================================="

curl -s "https://api.nextdns.io/profiles/$PROFILE/analytics/domains?status=blocked&limit=20" \
  -H "X-Api-Key: $API_KEY" | jq -r '.data[] | "\(.domain) — \(.queriesCount) queries"' | sort -t' ' -k3 -rn

echo ""
echo "Evaluación: Revisar manuales en Telegram si queries > 50 por dominio"
```

### 8. Historial de Cambios

| Fecha | Dominio | Acción | Razón |
|-------|---------|--------|-------|
| 2026-04-24 | a.root-servers.net | ✅ DESBLOQUEADO | DNS root — 1,246 queries |
| 2026-04-24 | m2.tuyacn.com | ✅ DESBLOQUEADO | Tuya MQTT — 2,332 queries |
| 2026-04-24 | api.amazonalexa.com | ✅ DESBLOQUEADO | Alexa API — crítica |
| — | — | — | — |

## AdGuard Home — Dominios en Whitelist

Los siguientes dominios fueron desbloqueados manualmente porque el filtro "Smart-TV Blocklist for AdGuard Home" los bloqueaba, impidiendo que LG Channels funcionara en el TV:

```
@@||lgtvsdp.com^
@@||lgappstv.com^
@@||lge.com^
```

Si LG Channels vuelve a fallar, verificar en AdGuard Home → Filters → Custom filtering rules que estas excepciones siguen presentes.

## AdGuard Home — Puertos (actualizado 2026-04-14)

- **DNS**: puerto **53** (UDP/TCP) — clientes LAN apuntan a 192.168.10.1:53 via DHCP option 6
- **API / Web UI**: puerto **3000** — http://192.168.10.1:3000
- **dnsmasq**: solo DHCP, DNS desactivado (`port=0`)

El chequeo de API usa `http://127.0.0.1:3000/control/status`.

## Servicios — Notas de Interpretación

- **mwan3**: No tiene un proceso único llamado `mwan3`. Corre como scripts de shell (`mwan3track`, `mwan3rtmon`). Verificar con `ps | grep mwan` o `/etc/init.d/mwan3 status` en lugar de `pidof mwan3`.
- **usteerd**: El proceso se llama `usteerd` (con d al final). `pidof usteer` fallará — usar `pidof usteerd`.
- **tailscaled**: El daemon es `tailscaled`. El binario CLI `tailscale` es diferente. Verificar proceso con `pidof tailscaled`.
- **WireGuard**: Ha sido desinstalado de Flint-2 (2026-04-04). Ya no es necesario verificar `wg0`.

## Usteer — DESINSTALADO (actualizado 2026-04-24)

### Estado
❌ **REMOVIDO** — Desinstalado 2026-04-24. Reemplazado con SSID adicional de 2.4GHz para mejor cobertura física.

### Razón de Desinstalación
Usteer proporciona WiFi steering automático (roaming inteligente), pero fue desinstalado el 2026-04-24 para reemplazarlo con una **SSID adicional de 2.4GHz**. 

**Compensación:**
- ❌ **Pérdida**: Sin roaming automático entre APs
- ✅ **Ganancia**: Mejor cobertura física en cuartos (penetración de paredes 2.4GHz)

### Proceso de Desinstalación (2026-04-24)
```bash
# Daemon fue matado manualmente
killall usteerd

# Paquete ya estaba removido
opkg remove usteer

# Sin referencias en autostart
grep -r 'usteer' /etc/init.d/ /etc/crontabs/  # (vacío)
```

### WiFi Networks Actuales (sin Usteer)
**Flint-2 y Beryl ahora tienen 5 SSIDs cada una:**
1. **AXTEL XTREMO** (5GHz)
2. **AXTEL XTREMO** (2.4GHz) ← **NUEVA** (agregada 2026-04-24)
3. **Mega_5G_A2DF** (5GHz)
4. **Mega_2.4G_A2DF** (2.4GHz)
5. **IOT** (2.4GHz)

Los clientes deben seleccionar manualmente la SSID con mejor señal en su ubicación.

### Verificación

```bash
# Confirmar que usteer está removido
pidof usteerd
# Debe retornar: (vacío)

# Ver SSIDs configuradas
uci show wireless | grep ssid

# Si necesitas reinstalar en el futuro (NO recomendado)
opkg update && opkg install usteer
```

### Notas para Sysupgrade

⚠️ Si haces **sysupgrade** en el futuro, estos scripts intentarán reinstalar usteer automáticamente:
- `/etc/script/post_openwrt25.sh`
- `/etc/script/post_upgrade25.sh`
- `/etc/script/post_upgrade_flint2.sh`

Para evitar reinstalación: `sed -i '/usteer/d' /etc/script/post_openwrt25.sh /etc/script/post_upgrade25.sh`

## WiFi Hotplug Tracker — AP-STA Event Monitoring (nuevo, 2026-05-24)

### Estado
✅ **PRODUCTIVO** — Captura eventos de conexión/desconexión WiFi en tiempo real (2026-05-24 21:20 UTC)

### Arquitectura

```
Dispositivo WiFi se conecta/desconecta
    ↓
hostapd genera AP-STA-CONNECTED / AP-STA-DISCONNECTED
    ↓
wpa_cli (en background vía hostapd_cli -B) captura evento
    ↓
Invoca handler: /etc/hotplug.d/wifi/50-client-tracker
    ↓
Handler (onhostchange.sh):
  - Resuelve hostname (DHCP leases → "NONAME"/"Desconocido")
  - Mapea interface phy*-ap* a SSID
  - Obtiene IP y MAC desde DHCP
  - Extrae bitrate vía iwinfo (CONNECT)
  - Formatea HTML para Telegram
  - Envía alerta
  - Registra en /var/log/wifi_client_tracker.log
```

### Procesos en Ejecución

**5 instancias activas de hostapd_cli:**
```
hostapd_cli -a /etc/hotplug.d/wifi/50-client-tracker -i phy0-ap0 -B  (IOT)
hostapd_cli -a /etc/hotplug.d/wifi/50-client-tracker -i phy0-ap1 -B  (Mega_2.4G_A2DF)
hostapd_cli -a /etc/hotplug.d/wifi/50-client-tracker -i phy0-ap2 -B  (AXTEL_XTREMO)
hostapd_cli -a /etc/hotplug.d/wifi/50-client-tracker -i phy1-ap0 -B  (AXTEL_XTREMO 5GHz)
hostapd_cli -a /etc/hotplug.d/wifi/50-client-tracker -i phy1-ap1 -B  (Mega_5G_A2DF)
```

### Interface Mappings

| Interface | SSID | Band |
|-----------|------|------|
| phy0-ap0 | IOT | 2.4GHz |
| phy0-ap1 | Mega_2.4G_A2DF | 2.4GHz |
| phy0-ap2 | AXTEL_XTREMO | 2.4GHz |
| phy1-ap0 | AXTEL_XTREMO | 5GHz |
| phy1-ap1 | Mega_5G_A2DF | 5GHz |

### Ejemplo de Alertas Telegram

#### 📱 AP-STA-CONNECTED
```
#iPhone connected on #AXTEL_XTREMO

Time: 2026-05-24 21:15:30
Hostname: iPhone
IP Address: 192.168.10.105
MAC Address: ba:30:61:dc:19:6a
ESSID: AXTEL_XTREMO
BitRate: 867 Mbps
```

#### 🔌 AP-STA-DISCONNECTED
```
#iPhone disconnected from #AXTEL_XTREMO

Time: 2026-05-24 21:12:34
Hostname: iPhone
IP Address: 192.168.10.105
MAC Address: ba:30:61:dc:19:6a
ESSID: AXTEL_XTREMO
```

### Archivo de Configuración

**Flint-2:**
- **Handler**: `/etc/hotplug.d/wifi/50-client-tracker` (phy*-ap* mappings)
- **Service**: `/etc/init.d/wifi-client-tracker` (inicia 5 procesos hostapd_cli)
- **Telegram Token**: REDACTED_BOT_TOKEN
- **Chat ID**: 716542586 (Flint2 notifications group)

**Beryl:**
- **Handler**: `/etc/hotplug.d/wifi/50-client-tracker` (phy*-ap* + wlan* mappings)
- **Service**: `/etc/init.d/wifi-client-tracker` (inicia 5 procesos hostapd_cli - MISMO que Flint-2)
- **Watchdog**: `/usr/bin/monitor/wifi_client_tracker_watchdog_beryl.sh` (EXPECTED=5, no 2)
- **Telegram Token**: REDACTED_BOT_TOKEN ✅ (bot de Beryl)
- **Chat ID**: 716542586 (mismo grupo)

**Log**: `/var/log/wifi_client_tracker.log` (eventos con timestamps)

### Persistencia

✅ Configurado en `/etc/sysupgrade.conf`:
```
/etc/hotplug.d/wifi/50-client-tracker
/etc/init.d/wifi-client-tracker
```

Sobrevive a sysupgrade automáticamente.

### Monitoreo en Tiempo Real

```bash
ssh root@192.168.10.1 'tail -f /var/log/wifi_client_tracker.log'
```

**Ejemplo de output:**
```
[2026-05-24 21:12:34] Event: interface=phy1-ap0 event=AP-STA-DISCONNECTED mac=ba:30:61:dc:19:6a
[2026-05-24 21:12:34] DISCONNECT: iPhone (ba:30:61:dc:19:6a) from AXTEL_XTREMO
[2026-05-24 21:15:30] Event: interface=phy1-ap0 event=AP-STA-CONNECTED mac=ba:30:61:dc:19:6a
[2026-05-24 21:15:30] CONNECT: iPhone (ba:30:61:dc:19:6a) to AXTEL_XTREMO (BitRate: 867Mbps)
```

### Verificación

```bash
# ¿Procesos hostapd_cli activos?
ps w | grep "hostapd_cli -a /etc/hotplug.d/wifi/50-client-tracker" | grep -v grep | wc -l
# Debe retornar: 5

# ¿Handler instalado?
test -f /etc/hotplug.d/wifi/50-client-tracker && echo "OK" || echo "MISSING"

# ¿Log escribiendo?
tail -3 /var/log/wifi_client_tracker.log
# Debe mostrar eventos recientes

# ¿Persistencia configurada?
grep -q "50-client-tracker" /etc/sysupgrade.conf && echo "OK" || echo "NOT CONFIGURED"
```

### Troubleshooting

| Problema | Síntoma | Solución |
|----------|---------|----------|
| No hay eventos en log | Log vacío o sin actualizaciones recientes | Reiniciar service: `/etc/init.d/wifi-client-tracker restart` |
| Solo DISCONNECT funciona | CONNECT no genera alertas | Verificar que handler usa `onhostchange.sh` correctamente |
| Telegram no recibe alertas | No hay Telegram pero log muestra eventos | Verificar token y chat ID en handler |
| Múltiples mensajes duplicados | Loop de mensajes para mismo evento | Verificar que no hay múltiples `hostapd_cli` para misma interfaz |

### Configuración Beryl (GL-MT3000) — Diferencias

**Topología igual a Flint-2 (5 interfaces):**

| Interface | SSID | Band | Proceso |
|-----------|------|------|---------|
| phy0-ap0 | Mega_2.4G_A2DF | 2.4GHz | ✅ hostapd_cli |
| phy0-ap2 | AXTEL XTREMO | 2.4GHz | ✅ hostapd_cli |
| phy1-ap0 | AXTEL XTREMO | 5GHz | ✅ hostapd_cli |
| wlan0-1 | IOT | 2.4GHz | ✅ hostapd_cli |
| wlan1-1 | Mega_5G_A2DF | 5GHz | ✅ hostapd_cli |

**Handler actualizado en Beryl (2026-05-24 22:30+):**
- ✅ 5 interface mappings (phy*-ap* + wlan*)
- ✅ Token correcto: `REDACTED_BOT_TOKEN`
- ✅ Watchdog: EXPECTED=5 (no 2)
- ✅ Service: inicia todos 5 procesos

**Verificación en Beryl:**
```bash
# ¿5 procesos activos?
ssh root@192.168.10.2 'ps w | grep "hostapd_cli -a /etc/hotplug.d/wifi/50-client-tracker" | grep -v grep | wc -l'
# Debe retornar: 5

# ¿Token configurado?
ssh root@192.168.10.2 'grep TELEGRAM_TOKEN /etc/hotplug.d/wifi/50-client-tracker | head -1'
# Debe mostrar: TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"

# ¿Procesos desglosados?
ssh root@192.168.10.2 'ps w | grep "hostapd_cli" | grep -v grep'
# Debe mostrar 5 líneas con phy0-ap0, phy0-ap2, phy1-ap0, wlan0-1, wlan1-1
```

## Problema Conocido: Alertas de CPU Falsas

### Síntoma
Alertas de "CPU al 90%+" que ocurren exactamente en minutos 0, 5, 10, etc.

### Causa
Múltiples scripts de monitoreo (`*/5 * * * *`) se ejecutan simultáneamente en las horas exactas (minuto 0), causando un pico real de CPU. El script `monitor_sistema.sh` mide el uso durante este pico.

### Solución Aplicada
Agregar delay aleatorio al inicio de `monitor_sistema.sh`:
```bash
sleep $(awk "BEGIN{print int(rand()*30)+5}")
```

### Verificación
Si `monitor_sistema.sh` tiene el delay:
```
grep 'sleep.*rand' /usr/bin/monitor/monitor_sistema.sh && echo "OK" || echo "FALTA DELAY"
```

### Scripts que corren en minuto 0 (contención)
Verificar con: `grep "^0 \* \* \* \*" /etc/crontabs/root | wc -l`
- Si > 10 scripts → riesgo de contención
- Considerar agregar delays aleatorios a otros scripts `*/5` también

## Response Format

Report results in a clear table format with ✅ OK / ⚠️ WARNING / ❌ ERROR per item.
Always suggest a fix if something is wrong.
If ARGUMENTS includes "notify", also send a Telegram message using:
- Token: from /etc/monitor/config.sh on the router
- Chat ID: 716542586

## Network Bandwidth Monitoring — nlbwmon (nuevo, 2026-04-11)

### Estado
- **nlbwmon v1.0+**: ✅ INSTALLED & OPERATIONAL
- **Database**: `/var/lib/nlbwmon/` (30-segundo refresh, 24-hour commit)
- **Límite de entradas**: 10,000 (evita llenar RAM/almacenamiento)

### Interfaces Monitoreadas
```
Interfaces de LAN:
  - br-lan.10 (LAN principal - VLANS)
  - br-lan.8 (VLAN IoT)

Interfaces de WAN:
  - wan / eth1 (Primary WAN — DHCP directo desde 2026-04-13)
  - lan1 (Secondary WAN)
  
Interfaces VPN:
  - tailscale0 (Tailscale exit node)
```

### Puertos Configurados para Monitoreo

| Puerto | Protocolo | Aplicación | Interfaz | Notas |
|--------|-----------|------------|----------|-------|
| **631** | TCP | IPP (Impresora) | br-lan.10 | Impresora de red |
| **139** | TCP | NetBIOS | br-lan.10 | SMB nombre resolution |
| **445** | TCP | SMB Direct | br-lan.10 | Compartir archivos Windows |
| **67** | UDP | DHCP Server | br-lan.10 | Server assignments |
| **68** | UDP | DHCP Client | br-lan.10 | Client leases |

### Puertos Excluidos

#### Puerto 5335 (Unbound DNS)
- **Razón**: Localhost-only traffic (127.0.0.1:5335)
- **Problema**: nlbwmon solo captura tráfico en interfaces de red (físicas/virtuales)
- **Limitación**: Port 5335 no atraviesa ninguna interfaz monitoreada
- **Alternativa**: Usar `unbound-control stats_noreset` para estadísticas de Unbound
- **Ejemplo**:
  ```sh
  ssh root@192.168.10.1 unbound-control stats_noreset | grep -E "num.queries|num.cachehits"
  ```

### Verificación en LuCI

```sh
# Ver tráfico monitoreado en tiempo real
ssh root@192.168.10.1 "cat /var/lib/nlbwmon/traffic4 2>/dev/null | tail -20"

# Verificar configuración
ssh root@192.168.10.1 "cat /etc/config/nlbwmon"

# Listar interfaces activas
ssh root@192.168.10.1 "nlbwmon -c /etc/config/nlbwmon 2>&1 | grep -i interface"
```

### Troubleshooting

**Puerto no aparece en LuCI**:
- Verificar que `nlbwmon` esté corriendo: `pidof nlbwmon`
- Revisar logs: `logread | grep nlbwmon`
- Recargar configuración: `/etc/init.d/nlbwmon restart`

**Alto uso de CPU/RAM**:
- Revisar número de entradas en DB: `wc -l /var/lib/nlbwmon/traffic4`
- Considerar reducir `database_limit` en `/etc/config/nlbwmon` si > 10000 entradas

---

## WiFi Clients Report by SSID (nuevo, 2026-04-11)

### Script: wifi_report.sh

**Funcionalidad**: Reporte de clientes WiFi desglosados por SSID (cada red WiFi). **Soporta ambos routers automáticamente** (detecta interfaces phy* y wlan*).

**Ubicación**: `/usr/bin/monitor/wifi_report.sh`

**Compatibilidad**:
- ✅ **Flint-2** (GL-MT6000): Detecta interfaces `phy0-ap*`, `phy1-ap*`
- ✅ **Beryl** (GL-MT3000): Detecta interfaces `wlan*`, `wlan*-1`
- Auto-detecta el formato de interfaz sin configuración manual

**Modos de Operación**:

1. **--summary** (default) - Resumen simple
   ```sh
   ssh root@192.168.10.1 /usr/bin/monitor/wifi_report.sh --summary
   ssh root@192.168.10.2 /usr/bin/monitor/wifi_report.sh --summary
   ```
   Ejemplo Flint-2:
   ```
   📊 WiFi Summary — Flint-2
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     Mega_5G_A2DF                   0 clientes
     AXTEL XTREMO                  32 clientes
     Mega_2.4G_A2DF                16 clientes
     IOT                           12 clientes
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     TOTAL: 60 clientes
   ```

2. **--live** - Dashboard en tiempo real (actualiza cada 10 segundos)
   ```sh
   ssh root@192.168.10.1 /usr/bin/monitor/wifi_report.sh --live
   ```
   Muestra:
   - Interfaz WiFi (phy0-ap0, wlan0, etc.) y SSID correspondiente
   - Número de clientes por SSID
   - MAC addresses, señal (RSSI) y throughput esperado (top 5)

3. **--report** - Envía reporte a Telegram
   ```sh
   ssh root@192.168.10.1 /usr/bin/monitor/wifi_report.sh --report
   ```
   Formato:
   ```
   🔌 *WiFi Report — Flint-2*
   2026-04-11 20:52 UTC

   *AXTEL XTREMO* (phy1-ap0)
   ├ Clientes: 32
   ├ [MAC1] [RSSI] ([throughput] Mbps)
   ├ [MAC2] [RSSI] ([throughput] Mbps)
   
   *Total: 60 clientes*
   ```

4. **--json** - Salida en formato JSON para integración
   ```sh
   ssh root@192.168.10.1 /usr/bin/monitor/wifi_report.sh --json
   ```

### Integración en Reportería Diaria

**Cron**: Agregado a `master_daily.sh` a las **08:00 AM** (después de DPI report)

```
run_task "wifi_report" "/usr/bin/monitor/wifi_report.sh --report"
```

Se ejecuta en ambos routers automáticamente.

**Información Capturada**:
- SSID de cada interfaz WiFi
- Número de clientes conectados por SSID
- MAC address de cada cliente
- Señal (RSSI en dBm)
- Throughput esperado (Mbps)

### Estadísticas Observadas (2026-04-11)

| Router | SSID | Clientes | Interfaces |
|--------|------|----------|------------|
| **Flint-2** | Mega_5G_A2DF | 0 | phy1-ap1 |
| | AXTEL XTREMO | 32 | phy1-ap0 |
| | Mega_2.4G_A2DF | 16 | phy0-ap1 |
| | IOT | 12 | phy0-ap0 |
| | **TOTAL** | **60** | — |
| **Beryl** | Mega_5G_A2DF | 4 | wlan1-1 |
| | AXTEL XTREMO | 4 | wlan1 |
| | IOT | 4 | wlan0-1 |
| | Mega_2.4G_A2DF | 4 | wlan0 |
| | **TOTAL** | **16** | — |

---

## Threat Alert System — C2 IP Blocking (nuevo, 2026-04-14)

### Estado de Instalación ✅

| Componente | Versión | Estado | Ubicación |
|-----------|---------|--------|-----------|
| **threat_feed_updater.sh** | 1.0 | ✅ OPERATIONAL | `/usr/local/lib/threat-alert/` |
| **anomaly_detector.sh** | 1.0 | ✅ OPERATIONAL | `/usr/local/lib/threat-alert/` |
| **security_monitor.sh** | 1.0 | ✅ OPERATIONAL | `/usr/local/lib/threat-alert/` |
| **Emerging Threats IPs** | 387 | ✅ LOADED | `/etc/threat-alert/feeds/emerging_c2_ips.txt` |
| **Cron Jobs** | 2 | ✅ SCHEDULED | `/etc/crontabs/root` |

### Qué es C2?

**C2 = Command & Control (Comando y Control)**

Servidores que usan atacantes para controlar máquinas infectadas con malware (botnet). El sistema bloquea 387 IPs conocidas de C2 detectadas por Emerging Threats.

### Feeds de Amenazas Activos

```
Emerging Threats C2 IPs:  387 servidores de Command & Control
URLhaus Malware Domains: ⚠️ Bloqueado por ISP (graceful degradation)
Actualización: Automática cada 12 horas (00:00 y 12:00 UTC)
```

### Verificación de Estado

```sh
# Ver lista actual de IPs C2 bloqueadas
ssh root@192.168.10.1 wc -l /etc/threat-alert/feeds/emerging_c2_ips.txt

# Verificar que actualización es automática
ssh root@192.168.10.1 grep threat_feed /etc/crontabs/root

# Ver última actualización
ssh root@192.168.10.1 ls -lt /etc/threat-alert/feeds/ | head -1

# Verificar que scripts tienen permiso de ejecución
ssh root@192.168.10.1 ls -lh /usr/local/lib/threat-alert/*.sh
```

### Comandos de Monitoreo

```sh
# 1. Ver amenaza actual (instantáneo)
ssh root@192.168.10.1 /usr/local/lib/threat-alert/security_monitor.sh --check

# 2. Ver amenaza en tiempo real (cada 10 segundos)
ssh root@192.168.10.1 /usr/local/bin/monitor_c2_blocks.sh

# 3. Ver logs de bloqueos de feeds
ssh root@192.168.10.1 tail -20 /var/log/threat-alert/updater.log

# 4. Ver logs de anomalías detectadas
ssh root@192.168.10.1 tail -20 /var/log/threat-alert/anomaly.log

# 5. Ver primeras 20 IPs C2 en lista
ssh root@192.168.10.1 head -20 /etc/threat-alert/feeds/emerging_c2_ips.txt

# 6. Forzar actualización manual de feeds
ssh root@192.168.10.1 /usr/local/lib/threat-alert/threat_feed_updater.sh
```

### Detección de Anomalías

El sistema detecta automáticamente:
- **Port Scanning**: Más de 20 puertos únicos por dispositivo en 5 min
- **SSH Brute Force**: Más de 5 intentos fallidos en 5 min
- **DNS Flooding**: Más de 100 queries en 10 segundos
- **Firewall Anomalies**: Surge anómalo en bloqueos de firewall

Alertas enviadas a Telegram cuando se detectan anomalías.

### Archivos de Configuración

```
/usr/local/lib/threat-alert/config.sh          Configuración (Telegram token, umbrales)
/etc/threat-alert/config.sh                    Copia de configuración
/etc/threat-alert/feeds/emerging_c2_ips.txt   Lista actual de IPs C2 (387 líneas)
/var/log/threat-alert/updater.log             Logs de actualización de feeds
/var/log/threat-alert/anomaly.log             Logs de detección de anomalías
```

### Threat Score (0-100)

**Cálculo de amenaza:**
- Firewall blocks > 50: +30 puntos
- Firewall blocks > 100: +30 más puntos
- SSH attempts > 5: +20 puntos
- SSH attempts > 20: +30 más puntos
- Connections > 100: +10 puntos
- Connections > 200: +20 más puntos

**Niveles:**
- 0-19: 🟢 NORMAL (sin amenaza)
- 20-49: 🟡 SOSPECHOSO (actividad anómala)
- 50+: 🔴 CRÍTICO (posible ataque en curso)

### Alertas Telegram

Tipos de alertas automáticas:
- 🔐 Feed update notifications (cada 12 horas)
- 🔴 Port Scanning detected
- ⚠️ SSH Brute Force detected
- 🌊 DNS Flooding detected
- 🚨 Firewall Block Anomaly detected
- 🔔 Test alerts (manual trigger)

### Cron Jobs Configurados

```
0 */12 * * * /usr/local/lib/threat-alert/threat_feed_updater.sh >> /var/log/threat-alert/updater.log 2>&1
*/5 * * * * /usr/local/lib/threat-alert/anomaly_detector.sh >> /var/log/threat-alert/anomaly.log 2>&1
```

**Horarios:**
- Feed update: 00:00 (medianoche) y 12:00 (mediodía) UTC
- Anomaly detection: Cada 5 minutos

### Troubleshooting

| Problema | Solución |
|----------|----------|
| URLhaus feed no descarga | Normal — ISP bloquea abuse.ch. Sistema funciona con Emerging Threats (387 IPs) |
| No veo bloqueos en logs | Completamente normal si red es limpia. Use comando `--check` para ver estado |
| Telegram no envía alertas | Verificar `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID` en `/etc/threat-alert/config.sh` |
| Scripts no ejecutan | Verificar permisos: `chmod +x /usr/local/lib/threat-alert/*.sh` |
| Feeds no se actualizan | Verificar cron: `grep threat_feed /etc/crontabs/root` |

### Verificación Rápida en Router Check

Agregar estos comandos al check automático:

```sh
# Threat Alert System
threat_feeds=$(wc -l < /etc/threat-alert/feeds/emerging_c2_ips.txt 2>/dev/null || echo "0")
echo "Threat Alert System:"
echo "  C2 IPs monitoreadas: $threat_feeds"
echo "  Feed updater: $(pidof threat_feed_updater.sh >/dev/null && echo 'OK' || echo 'scheduled')"
echo "  Last feed update: $(ls -lt /etc/threat-alert/feeds/ 2>/dev/null | head -1 | awk '{print $6" "$7" "$8}')"
echo "  Anomaly detector: running via cron"
```

---

## DPI — Deep Packet Inspection (nuevo, 2026-04-11)

### Sistema Activo ✅

| Componente | Versión | Estado | Ubicación |
|-----------|---------|--------|-----------|
| **netifyd** | 4.4.7 | ✅ RUNNING | Daemon principal (aarch64, conntrack, netlink, dns-cache, plugins, regex) |
| **libndpi** | 5.0.0 | ✅ INSTALLED | 2.4MB - Librería de clasificación |
| **CrowdSec** | Active | ✅ RUNNING | Análisis complementario de seguridad |

### Archivos y Caché

```
Socket UNIX:           /var/run/netifyd/netifyd.sock
Flow Hash Cache:       /etc/netify.d/flow-hash-cache.dat (385.5KB)
DNS Cache Entries:     /etc/netify.d/dns-cache.csv (62.7K)
Applications DB:       /etc/netify.d/netify-apps.conf (135.2K)
Categories:            /etc/netify.d/netify-categories.json (16.7K)
Config Principal:      /etc/netifyd.conf
Config UCI:            /etc/config/netifyd (enabled=1, autoconfig=1)
Status JSON:           /var/run/netifyd/status.json
PID File:              /var/run/netifyd/netifyd.pid
```

### Capacidades de Detección

**Protocolos Detectables** (35+):
- **Web/Mail**: HTTP, HTTPS, DNS, FTP, SMTP, IMAP, POP3
- **File Transfer**: NFS, SMBv1, SSH, BitTorrent, Gnutella
- **Network**: DHCP, NTP, SNMP, BGP, SYSLOG, XDMCP, CoAP
- **Database**: MySQL, PostgreSQL
- **Other**: VMware, Skype, Facebook, YouTube, etc.

**Metadata Capturada**:
- IP origen/destino
- Puertos
- Aplicación detectada (clasificación)
- Categoría (redes sociales, streaming, software, etc.)
- Estadísticas de flujo
- Hit rate en caché DNS (59-70% típico)

### Comandos de Verificación

```sh
# Verificar que netifyd está activo
ssh root@192.168.10.1 "pidof netifyd && echo 'netifyd: OK' || echo 'netifyd: STOPPED'"

# Ver estado en tiempo real
ssh root@192.168.10.1 "/usr/bin/monitor/dpi_report.sh --live"

# Generar reporte
ssh root@192.168.10.1 "/usr/bin/monitor/dpi_report.sh --report"

# Verificar socket
ssh root@192.168.10.1 "ls -lh /var/run/netifyd/netifyd.sock"

# Ver clasificaciones de aplicaciones
ssh root@192.168.10.1 "head -20 /etc/netify.d/netify-apps.conf"
```

### Reportería Automática

**Cron Schedule** (en master_daily.sh):
```
08:00 AM diarios → /usr/bin/monitor/dpi_report.sh --report
```

**Scripts de Reportería**:
- **dpi_report.sh**: Shell wrapper con modos `--live` (dashboard) y `--report` (Telegram)
- **dpi_report.py**: Implementación Python que lee datos del socket, procesa estadísticas, envía reportes

### Estadísticas Típicas (2026-04-11)

- **Flow cache**: 385.5KB (flujos clasificados)
- **DNS cache entries**: ~62.7K resoluciones
- **Applications DB**: 17,000+ identificables
- **Protocolos detectables**: 35+ tipos
- **Autoconfiguración**: Detecta automáticamente interfaces LAN/WAN

### Notas Operativas

1. **Socket UNIX**: netifyd usa `/var/run/netifyd/netifyd.sock`, no escucha en TCP/IP
2. **Persistencia**: Cache se mantiene entre reinicios (archivos en `/etc/netify.d/`)
3. **Señales internas**: RT35 periódicamente es normal
4. **Complementario**: CrowdSec proporciona análisis de seguridad adicional
5. **Hit Rate en DNS**: 59-70% indica caché efectivo (mejora con tiempo)

---

## USB Auto-Mount & Post-Restore (nuevo, 2026-04-13)

### Problema resuelto
**Antes**: Después de sysupgrade (restauración), USB no se montaba automáticamente, perdía todos los scripts y configuración
**Ahora**: USB se monta automáticamente y todos los scripts se restauran desde USB sin intervención manual

### Solución de 3 capas

#### 1. Script Init.d: `/etc/init.d/usb-mount`
- Ejecuta al arrancar (START=25, STOP=90)
- Espera hasta 10 segundos a que `/dev/sda1` se detecte
- Monta `/dev/sda1` → `/mnt/usb` automáticamente
- Crea directorios esenciales: `config-sync/`, `monitor/`
- **No depende de UUID** — funciona con cualquier restauración

#### 2. Redundancia en rc.local
- Chequeo adicional que se ejecuta al final del arranque
- Si USB no está montado, lo monta como último recurso
- Detecta post-restauración (ausencia de `/usr/bin/monitor/master_realtime.sh`)

#### 3. Post-Restore Script: `/etc/script/post_restore.sh`
- Se dispara automáticamente si detecta restauración
- Restaura desde USB automáticamente:
  - `/usr/bin/monitor/` (50 scripts)
  - `/etc/script/` (40 scripts)
  - UCI configs (network, firewall, dhcp, mwan3, etc.)
  - Crontab
  - AdGuardHome config
  - Firewall rules
  - Reinicia servicios críticos

### Flujo de Restauración

```
1. Usuario hace sysupgrade
   ↓
2. Router arranca → /etc/init.d/usb-mount monta USB
   ↓
3. /etc/rc.local detecta post-restauración
   ↓
4. /etc/script/post_restore.sh restaura TODO automáticamente (5-10 minutos)
   ↓
5. Todo funciona como antes ✓
```

### Backup Automático (diario 02:00 UTC)

`/etc/script/config_sync.sh` guarda en `/mnt/usb/config-sync/`:
- Scripts monitor y script
- UCI configs (newest versions)
- Crontab
- Configs críticas (AGH, firewall, etc.)
- Directorio monitor/

### Verificación

```sh
# ¿USB está montado?
mount | grep usb

# ¿Scripts init.d?
ls -la /etc/init.d/usb-mount
ls -la /etc/script/post_restore.sh

# ¿Backup automático?
ls -lh /mnt/usb/config-sync/ | head -20
```

---

## Telegram Notifications

**Sistema centralizado de notificaciones en grupo con prefijos temáticos:**

- **Grupo**: "Flint2 notifications" (ID: -1003951418154)
- **Chat ID**: `-1003951418154`
- **Función**: `send_telegram(mensaje, prefijo)` en `/etc/monitor/config.sh`

### Prefijos por Tema

| Prefijo | Scripts | Hora | Descripción |
|---------|---------|------|-------------|
| `[MWAN3]` | failover_notify.sh, mwan3_test.sh | Tiempo real + 02:00 | WAN cambios, latencias, downtime |
| `[BACKUP]` | backup_new.sh, config_sync.sh | 03:00, 02:00 | Backups y sincronización USB |
| `[HEALTH]` | mac_report.sh | 02:00 | Nuevos dispositivos MAC, estado |
| `[SYSTEM]` | reporte_diario.sh, log_cleaner.sh | 02:00 | Uptime, RAM, CPU, Servicios |
| `[WIFI]` | wifi_report.sh | 08:00 | Clientes por SSID, estadísticas |

### Notificaciones en Tiempo Real

- **failover_notify.sh**: WAN cambios (online/offline) con duración de downtime
  - Ejemplo: `[MWAN3] 🟢 WAN Axtel volvió ONLINE | Duración: 5m 23s`
- **backup_new.sh**: Éxito/fallo de backups
  - Ejemplo: `[BACKUP] ✅ BACKUP COMPLETADO | 247MB`

---

## Internet Detector — WAN Monitoring (actualizado 2026-04-15)

### Estado
✅ **OPERATIVO** — Monitorea conectividad de ambas WANs

### Configuración
- **Instancia 1 (internet)**: Telmex WAN — eth1 (pppoe-wan)
  - Ping a: 45.90.28.0, 45.90.30.0 (NextDNS bootstrap)
  - **Módulo mod_public_ip**: ❌ **DESACTIVADO** (2026-04-15 — causaba falsas desconexiones)
  
- **Instancia 2 (secondwan)**: Megacable WAN — lan1
  - Misma configuración de ping
  - **Módulo mod_public_ip**: ❌ **DESACTIVADO**

### Cambio Reciente
**2026-04-15**: Desactivación de `mod_public_ip_enabled` en ambas instancias
- **Problema**: Módulo intentaba obtener IP pública vía HTTP (checkip.amazonaws.com) que fallaba intermitentemente
- **Síntoma**: Falsas alertas de "Disconnected/Connected" cada 10-30 minutos
- **Solución**: Desactivar módulo, confiar solo en ping (verificado con MWAN3 que WANs estaban online 21+ horas)
- **Resultado**: ✅ Cero falsos positivos, alertas solo en desconexiones reales

### Verificación
```bash
# Ver estado del internet-detector
ssh root@192.168.10.1 "ps | grep internet-detector | grep -v grep"

# Ver logs (últimas líneas sin errores de HTTP)
ssh root@192.168.10.1 "logread | grep internet-detector | tail -5"

# Confirmar mod_public_ip desactivado
ssh root@192.168.10.1 "grep 'mod_public_ip_enabled' /etc/config/internet-detector"
# Debería mostrar: '0' en ambas instancias
```

---

## NextDNS Quota Monitor — Seguimiento de Queries (actualizado 2026-04-15)

### Estado
✅ **OPERATIVO** — Monitorea cuota de 300,000 queries/mes

### Características
- **Método**: API de NextDNS (endpoint: `/profiles/47a69f/analytics/status` — CORREGIDO 2026-04-15)
- **API Key**: Configurada (`35fcdecd8d64df3b7b0003011d05996fbf703330`)
- **Actualización**: Automática cada hora vía cron + diaria a las 08:00 AM
- **Alertas Telegram**: Se envían si uso > 80% o > 95%

### Corrección de API (2026-04-15)
**Problema anterior**: Script usaba endpoint `/v1/profiles/...` que no existe (devolvía "notFound")
- ❌ `https://api.nextdns.io/v1/profiles/.../analytics/queries` — No existe
- ✅ `https://api.nextdns.io/profiles/.../analytics/status` — **Correcto**

**Solución**: Script actualizado para usar endpoint correcto y sumar queries de todos los estados:
- `default` queries: 77,282
- `blocked` queries: 877
- `relayed` queries: 133
- **TOTAL: 78,295 queries**

### Estado Actual (2026-04-15 10:21 UTC)
```
Queries:     78,295 / 300,000 (26%)
Restante:    221,705 queries
Promedio:    5,219 queries/día
Proyección:  ~156,570 queries a fin de mes (dentro del límite)
Status:      🟢 OK
```

### Cron Jobs
```bash
# Cada hora (minuto 0)
0 * * * * /usr/local/bin/nextdns_quota_monitor.sh --alert

# Diariamente a las 08:00 AM (con proyección)
0 8 * * * /usr/local/bin/nextdns_quota_monitor.sh --alert
```

### Comandos Disponibles
```bash
# Ver uso actual
ssh root@192.168.10.1 '/usr/local/bin/nextdns_quota_monitor.sh --check'

# Dashboard en vivo (10 seg refresh)
ssh root@192.168.10.1 '/usr/local/bin/nextdns_quota_monitor.sh --live'

# Actualizar manual (si lo necesitas)
ssh root@192.168.10.1 '/usr/local/bin/nextdns_quota_monitor.sh --set-queries 78295'
```

### Troubleshooting
- **API no responde**: Verificar que `NEXTDNS_API_KEY` esté configurada en `/usr/local/bin/nextdns_quota_monitor.sh`
- **Cron no ejecuta**: Verificar con `ssh root@192.168.10.1 "crontab -l | grep nextdns"`
- **Logs**: `ssh root@192.168.10.1 "tail -20 /var/log/nextdns_quota.log"`

---

## MWAN3 Tracking — Configuración Anti-Flapping (actualizado 2026-04-17)

### Umbrales actuales (menos sensibles)

| Parámetro | wan | secondwan | Significado |
|-----------|-----|-----------|-------------|
| `reliability` | 2 | 2 | 2 de 3 IPs deben fallar (antes: 1 de 3) |
| `interval` | 5s | 5s | Ping cada 5s (antes: 3s) |
| `timeout` | 6s | 6s | Timeout por ping (antes: 4s) |
| `down` | 5 | 5 | Fallos consecutivos para declarar DOWN (antes: 3) |
| `failure_latency` | 250ms | 250ms | Latencia que se considera fallo (antes: 100/150ms) |
| `recovery_latency` | 120ms | 150ms | Latencia para considerar recuperado |

**Tiempo mínimo para declarar WAN caída**: 5 fallos × 5s = **25 segundos** (antes: 9 segundos)

**Verificación:**
```sh
uci show mwan3.wan | grep -E "reliability|interval|timeout|down|failure_latency"
uci show mwan3.secondwan | grep -E "reliability|interval|timeout|down|failure_latency"
mwan3 status
```

---

## WiFi — Configuración 2.4GHz (actualizado 2026-04-17)

### Cambios aplicados en radio0 (2.4GHz)

| Parámetro | Valor | Archivo |
|-----------|-------|---------|
| `legacy_rates` | `0` | `wireless.radio0` |
| `max_inactivity` | `600s` | `wireless.guest2g` (Mega_2.4G_A2DF) |
| `max_inactivity` | `600s` | `wireless.wifinet3` (IOT) |

- `legacy_rates=0`: Deshabilita tasas 802.11b (1/2/5.5/6 Mbps). Tasa mínima sube a 11 Mbps.
- `max_inactivity=600s`: AP espera 600s antes de desconectar cliente inactivo (default 300s, antes 900s en guest2g).

**Nota sobre dispositivo IoT flapper** (`d0:a0:bb:7d:9f:a8`, `iot-d0a0bb`):
- SSID: Mega_2.4G_A2DF (phy0-ap1), IP: 192.168.8.110
- Patrón: reconecta cada ~42s con DHCP discover
- Causa: firmware TP-Link con power-saving agresivo (tx bitrate cae a 6 Mbps)
- Mitigación aplicada: IP estática DHCP (`host[9]` en `/etc/config/dhcp`) + legacy_rates=0
- El flapping WiFi persiste (inicia el cliente, no el AP), pero el DHCP storm se redujo

**Verificación:**
```sh
uci show wireless.radio0 | grep legacy_rates
uci show wireless.guest2g | grep inactivity
iw dev phy0-ap1 station get d0:a0:bb:7d:9f:a8 | grep "tx bitrate"
```

---

## Speedtest on WAN Recovery — v4 (actualizado 2026-04-17)

**Script**: `/usr/bin/monitor/speedtest_check.sh` (llamado desde `/etc/mwan3.user`)

### Cambios v4 vs versiones anteriores

| Fix | Descripción |
|-----|-------------|
| **`-i $WAN_IP`** | Fuerza interfaz correcta → elimina crash `std::logic_error` con MWAN3 dual-WAN |
| **`× 8 / 1,000,000`** | Conversión correcta bytes/s → Mbps (antes: daba 44 MB/s en lugar de 352 Mbps) |
| **Retry logic** | Si falla → espera 30s y reintenta antes de reportar error |
| **WAIT_TIME=60s** | Sube de 30s a 60s para dar tiempo a MWAN3 de estabilizar rutas |
| **Upload + URL** | Mensaje Telegram ahora incluye velocidad de subida y enlace al resultado |

### Thresholds y routing
- **Telmex** (wan → eth1 → 192.168.1.74): umbral 350 Mbps
- **Megacable** (secondwan → lan1 → 192.168.100.26): umbral 210 Mbps

### Velocidades verificadas (2026-04-17)
```
Telmex:    📥 352.6 Mbps  📤 361.0 Mbps  ⏱️ 2.9ms  ✅ OK
Megacable: 📥 210.1 Mbps  📤 209.7 Mbps  ⏱️ 2.9ms  ✅ OK
```

### Error conocido resuelto
**`std::logic_error` crash**: Ocurre cuando el binario Ookla se ejecuta sin `-i` flag en sistema con MWAN3 activo — las tablas de routing en transición causan excepción en el binario C++. Solución: siempre pasar `-i $WAN_IP`.

---

## Speedtest Hourly Monitoring — v1 (nuevo, 2026-05-11)

**Script**: `/usr/bin/monitor/speedtest_monitor.sh` (ejecutado vía cron cada hora)

### Propósito
Monitoreo continuo de velocidad de descarga en ambas WANs con alertas automáticas si cae por debajo del 80% de la velocidad esperada.

### Cron Configuration
```bash
# Telmex (wan) — cada hora a minuto 7
7 * * * * /usr/bin/monitor/speedtest_monitor.sh wan 80

# Megacable (secondwan) — cada hora a minuto 17
17 * * * * /usr/bin/monitor/speedtest_monitor.sh secondwan 80
```

**Frecuencia**: 24 ejecuciones diarias (cada hora) para cada WAN

### Umbrales y Alertas

| WAN | Velocidad esperada | 80% umbral | Alert | Acción |
|-----|-------------------|-----------|-------|--------|
| Telmex (wan) | 350 Mbps | 280 Mbps | 🔴 CRÍTICA | Envía notificación Telegram |
| Megacable (secondwan) | 210 Mbps | 168 Mbps | 🔴 CRÍTICA | Envía notificación Telegram |

### Flujo de Ejecución
1. Ejecuta `speedtest_check.sh` para la interfaz (wan o secondwan)
2. Parsea JSON output → extrae `download` en Mbps
3. Calcula umbral: velocidad_esperada × (porcentaje / 100)
4. Compara actual vs umbral
5. Si actual < umbral → **Alerta Telegram 🔴**
6. Registra resultado en log correspondiente

### Ejemplo de Mensaje de Alerta (cuando cae por debajo)

```
🔴 SPEEDTEST ALERTA — Telmex
⚠️ Velocidad baja
📥 245 Mbps (umbral: 280 Mbps)
⏱️ ping: 3.2ms
🔗 https://www.speedtest.net/result/c/...
🔴 Velocidad por debajo del 80% esperado
```

### Logs
- **Telmex**: `/var/log/speedtest_monitor_wan.log`
- **Megacable**: `/var/log/speedtest_monitor_secondwan.log`

Cada línea incluye timestamp UTC, velocidad detectada, umbral y estado (✅ OK o 🔴 ALERTA)

### Configuración de Umbrales
**Cambiar en cron:**
```bash
# Reducir a 75%
7 * * * * /usr/bin/monitor/speedtest_monitor.sh wan 75

# Aumentar a 90%
7 * * * * /usr/bin/monitor/speedtest_monitor.sh wan 90
```

**Cambiar velocidad esperada:**
Editar en `/usr/bin/monitor/speedtest_monitor.sh`:
```bash
WAN_SPEEDS_wan=350        # Cambiar a velocidad real esperada
WAN_SPEEDS_secondwan=210  # Cambiar a velocidad real esperada
```

### Integración con Otros Sistemas
- **speedtest_check.sh (v6+)**: Ejecuta speedtest real en failover/recovery desde `/etc/mwan3.user`
- **speedtest_monitor.sh (v1)**: Monitoreo horario continuo desde cron
- Ambos comparten binario `/etc/script/speedtest` y función `send_telegram()` desde `/etc/monitor/config.sh`

### Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| Alertas frecuentes (>3/día) | ISP degradado o throttling | Revisar logs, contactar ISP, considerar reducir umbral |
| No hay alertas | Cron no se ejecuta | Verificar crontab con `crontab -l` y revisar `/var/log/syslog` |
| Speedtest falla ("TIMEOUT") | Red muy lenta | Aumentar timeout en speedtest_check.sh (línea TIMEOUT=120) |
| Telegram no recibe alertas | config.sh sin función send_telegram | Verificar `/etc/monitor/config.sh` tiene función send_telegram |
| Logs no se crean | Permisos insuficientes | Ejecutar `chmod 755 /usr/bin/monitor/speedtest_monitor.sh` |

### Comandos de Verificación
```bash
# Ver última ejecución (Telmex)
tail -5 /var/log/speedtest_monitor_wan.log

# Ver última ejecución (Megacable)
tail -5 /var/log/speedtest_monitor_secondwan.log

# Ejecutar manualmente
/usr/bin/monitor/speedtest_monitor.sh wan 80

# Ver crontab activo
crontab -l | grep speedtest_monitor
```

---

## WAN DNS Configuration (actualizado 2026-04-24)

### Configuración Actual

| Interfaz | Primario | Fallback 1 | Fallback 2 | peerdns |
|----------|----------|-----------|-----------|---------|
| **wan** (Telmex) | 127.0.0.1 | 45.90.28.245 | 45.90.30.245 | 0 |
| **secondwan** (Megacable) | 127.0.0.1 | 45.90.28.245 | 45.90.30.245 | 0 |

### Razón

- **Primario 127.0.0.1**: Todo DNS pasa por AdGuardHome (logs, filtros, control)
- **Fallback NextDNS Anycast**: Si AGH falla, router usa NextDNS con perfil 29e346 específico
- **peerdns=0**: NO usar DNS del ISP (evita censura/bloqueos de carriers)

### Jerarquía DNS

```
1. AGH:53 (127.0.0.1) — Control total
   └─ Unbound:5335 — Caché + recursive
      └─ NextDNS DoT (tls://29e346)
2. Fallback NextDNS Anycast (45.90.28.245, 45.90.30.245)
```

### Verificación

```bash
uci show network.wan.dns
uci show network.secondwan.dns
# Debe mostrar: 127.0.0.1 45.90.28.245 45.90.30.245

# Test fallback manual
nslookup google.com 45.90.28.245
```

## IoT VLAN DNS (actualizado 2026-04-24)

### Configuración Correcta

```
dhcp.IOT.dhcp_option='6,192.168.8.1'
```

**Cambio (2026-04-24):** Removido fallback directo a NextDNS Anycast (45.90.28.245/30.245)

**Razón:** Evitar queries encriptadas sin registro en AGH

**Impacto:** Problema del "33% encriptado" resuelto

### Flujo IoT

```
Dispositivo IoT → 192.168.8.1:53 (AGH)
              → 127.0.0.1:5335 (Unbound)
              → NextDNS fallback
```

---

## Changelog

### v1.17.0 (2026-05-11)
- **Speedtest Hourly Monitoring Service**: Nuevo servicio continuo de monitoreo de velocidad
  - ✅ Script `/usr/bin/monitor/speedtest_monitor.sh` ejecutado 24 veces al día (cada hora)
  - ✅ Alertas automáticas si velocidad cae por debajo del 80% del umbral esperado
  - ✅ Umbrales: Telmex 280 Mbps (80% de 350), Megacable 168 Mbps (80% de 210)
  - ✅ Cron configurado: `7 * * * * /usr/bin/monitor/speedtest_monitor.sh wan 80`
  - ✅ Cron configurado: `17 * * * * /usr/bin/monitor/speedtest_monitor.sh secondwan 80`
  - ✅ Logs separados: `/var/log/speedtest_monitor_wan.log` y `/var/log/speedtest_monitor_secondwan.log`
  - ✅ Mensajes Telegram con 🔴 ALERTA cuando cae velocidad
  - ✅ Parámetro de porcentaje editable (default 80%) para ajustar sensibilidad
  - Documentación: Nueva sección "Speedtest Hourly Monitoring — v1" agregada
  - Impacto: Detección inmediata de degradación de ISP (máximo 1 hora entre checks)

### v1.16.0 (2026-04-27)
- **AdGuard Home — Puerto API Corregido**: Actualizado script para usar puerto correcto
  - ❌ Error anterior: Script intentaba conectarse a `http://127.0.0.1:3053/control/status` (puerto inexistente)
  - ✅ Corrección: Cambio a `http://127.0.0.1:3000/control/status` (puerto API/GUI correcto)
  - ✅ Documentación: Aclarado que AGH escucha en puerto 53 (DNS) y puerto 3000 (API/GUI)
  - Impacto: Health check de AGH ahora funciona correctamente
  - Nota: v1.3.1 mencionaba corrección a 3000, pero no fue aplicada completamente — corregido en esta versión

### v1.15.0 (2026-04-24)
- **DNS WAN Fallback Configuration**: Configuradas WANs con NextDNS Anycast como fallback
  - ✅ WAN Principal (Telmex): 127.0.0.1 | 45.90.28.245 | 45.90.30.245
  - ✅ WAN Secundaria (Megacable): 127.0.0.1 | 45.90.28.245 | 45.90.30.245
  - ✅ peerdns='0' en ambas (no usar DNS del ISP)
  - ✅ Fallback a NextDNS perfil específico (29e346), no genérico
  - Razón: Si AGH falla, router tiene fallback externo seguro
  - Impacto: Máxima resiliencia sin depender de carriers

- **IoT VLAN DNS — Corregida**: Removido bypass directo a NextDNS
  - ❌ Antes: `dhcp.IOT.dhcp_option='6,192.168.8.1' '42,45.90.28.245,45.90.30.245'`
  - ✅ Ahora: `dhcp.IOT.dhcp_option='6,192.168.8.1'`
  - Problema resuelto: 33% de queries encriptadas (sin monitoreo AGH)
  - Resultado: Todas las queries pasan por AGH, visibilidad 100%

- **NextDNS Anycast Específico**: Confirmado uso de 45.90.28.245 y 45.90.30.245
  - ⚠️ NO usar 45.90.28.0 (genérico, sin filtros del perfil)
  - ✅ Usar .245 que es específico del perfil 29e346

- **Skill documentation**: Agregadas secciones de WAN DNS Configuration e IoT VLAN DNS

### v1.14.0 (2026-04-24)
- **NextDNS Critical Domains Synchronization**: Nuevo sistema automático para sincronizar dominios críticos al whitelist
  - ✅ Script `/usr/local/bin/nextdns_sync.sh` automático
  - ✅ 3 dominios críticos agregados al whitelist NextDNS:
    - a.root-servers.net (DNS root — 1,246 queries bloqueadas)
    - m2.tuyacn.com (Tuya MQTT para LG AC — 2,332 queries bloqueadas)
    - api.amazonalexa.com (Amazon Alexa API)
  - ✅ Ejecución manual inmediata + Cron nightly (02:00 UTC)
  - ✅ Log: `/var/log/nextdns_sync.log`
  - Resultado: 5 dominios nuevos agregados, 2 ya existentes, 0 errores (2026-04-24 13:37 UTC)
- **Perfil NextDNS actualizado**: Cambio de 47a69f a 29e346
  - Configuración actualizada en script de sincronización
  - Documentación del skill actualizada
- **Impacto operativo**:
  - LGE_AC2_open: Recupera conectividad MQTT a Tuya (sin desconexiones)
  - amazon-630ca9591: Recupera conectividad a Alexa API (responde a comandos)
  - DNS global: Root server ahora sin bloqueos (resolución más rápida)

### v1.13.0 (2026-04-20)
- **SSID IoT Network Fix**: Mega_2.4G_A2DF y Mega_5G_A2DF corregidas de LAN a IOT VLAN
  - Problema: SSIDs estaban en la red LAN en lugar de IOT, causando flapping en dispositivos IoT
  - Solución: `uci set wireless.guest2g.network='IOT'` y `uci set wireless.guest5g.network='IOT'`
  - Resultado: Dispositivos IoT con DHCP leases estables, sin flapping

### v1.12.0 (2026-04-17)
- **Tailscale Exit Node — Firewall Fixes**: Corregidas reglas que usaban `pppoe-wan` (inexistente desde 2026-04-13)
  - ❌ Problema: Forward rule y masquerade rules referenciaban `pppoe-wan` en lugar de `eth1` (WAN primaria actual)
  - ✅ Solución: Actualizar `/etc/firewall.user` líneas 3-5 para usar `eth1` (DHCP) en lugar de `pppoe-wan`
  - ✅ Verificación: Forward rule ahora muestra `oifname { "eth1", "lan1" }` con counter activo
  - ✅ Resultado: Exit node ahora funciona correctamente — iPhone puede seleccionar Flint-2 para salida a internet
  - Cambios: 
    - Forward: `oifname { "eth1", "lan1" }` (era `pppoe-wan`)
    - Masquerade: `oifname "eth1" iifname "tailscale0"` (era `pppoe-wan`)
- **DHCP LAN — Lease time actualizado**: Reducido de 72h a 24h
  - Razón: 72h es demasiado largo — cambios de configuración DNS tardan hasta 3 días en propagarse
  - Cambio: `uci set dhcp.lan.leasetime='24h'`
  - Ventaja: Nuevas leases renuevan en 24h, cambios de red se propagan más rápido
  - IoT: se mantiene en 24h (correcto para dispositivos semi-permanentes)
- **Skill documentation**: Actualizada con configuración actual (eth1, no pppoe-wan)

### v1.11.0 (2026-04-17)
- **Anti-Flapping MWAN3**: Umbrales menos sensibles para reducir flappings por picos transitorios
  - `reliability` 1→2: necesita 2 de 3 IPs fallando (no 1)
  - `interval` 3s→5s, `timeout` 4s→6s, `down` 3→5, `failure_latency` 100ms→250ms
  - Tiempo mínimo para declarar WAN caída: 25s (antes: 9s)
- **Watchdog Unbound**: Reducida ventana de outage de 5 min a 1 min
  - Cron `*/5` → `* * * * *` con guard `[ -z "$(pidof unbound)" ]`
- **WiFi 2.4GHz**: Deshabilita legacy rates 802.11b (`legacy_rates=0` en radio0)
  - Tasa mínima sube de 6 Mbps a 11 Mbps
  - `max_inactivity=600s` en SSIDs Mega_2.4G_A2DF e IOT
- **DHCP estático IoT**: Confirmada reserva para `d0:a0:bb:7d:9f:a8` → 192.168.8.110
- **Speedtest v4**: Correcciones críticas en `speedtest_check.sh`
  - Fix `-i $WAN_IP`: elimina crash `std::logic_error` con MWAN3 dual-WAN
  - Fix conversión bytes→Mbps: `× 8 / 1,000,000` (antes: reportaba MB/s en lugar de Mbps)
  - Retry logic + WAIT_TIME=60s + Upload + URL en mensaje Telegram
  - Verificado: Telmex 352.6 Mbps, Megacable 210.1 Mbps ✅
- **DNS**: Actualizada arquitectura — AGH:53 → Unbound:5335 (recursive + auth-zones ICANN)
  - Hit rate Unbound: 63.8%  |  NextDNS: 118K/300K queries/mes
  - `validator_ntp=0` crítico para generar auth-zones
  - `module-config: "respip iterator"` (sin validator) para evitar SERVFAIL

### v1.10.0 (2026-04-15)
- **Internet Detector**: Desactivado módulo `mod_public_ip` que causaba falsas desconexiones
  - ❌ Problema: Errores HTTP intermitentes al obtener IP pública vía checkip.amazonaws.com cada 10-30 min
  - ✅ Solución: Confiar solo en ping a NextDNS bootstrap (más confiable)
  - ✅ Resultado: Cero falsos positivos, alertas solo en desconexiones reales
- **NextDNS Quota Monitor**: Reparada API de NextDNS y ahora funciona 100% automáticamente
  - ❌ Problema: Script usaba endpoint incorrecto `/v1/profiles/...` (no existe)
  - ✅ Solución: Cambio a endpoint correcto `/profiles/.../analytics/status`
  - ✅ Resultado: API devuelve datos en tiempo real, queries actualizadas automáticamente cada hora
  - ✅ Cron configurado: Alertas cada hora + diaria a las 08:00 AM con proyección
- **Documentación**: Nuevas secciones completas para ambos sistemas

### v1.9.0 (2026-04-14)
- **Threat Alert System — C2 IP Blocking**: Sistema completo de detección de amenazas instalado y operacional
  - ✅ 387 IPs de C2 (Command & Control) desde Emerging Threats bloqueadas automáticamente
  - ✅ Detector de anomalías: port scanning, SSH brute force, DNS flooding, firewall anomalies
  - ✅ Monitor en tiempo real: dashboard con threat score (0-100) actualizado cada 5 segundos
  - ✅ Feeds automáticos: actualización cada 12 horas con nuevas amenazas descubiertas
  - ✅ Alertas Telegram: notificaciones automáticas cuando detecta anomalías
  - ✅ Comandos disponibles: `security_monitor.sh --check/--live/--alert`
  - ✅ Monitoreo en tiempo real: `/usr/local/bin/monitor_c2_blocks.sh`
  - Scripts: threat_feed_updater.sh, anomaly_detector.sh, security_monitor.sh
  - Cron jobs: feed update @00:00 & @12:00, anomaly detection @*/5
  - Graceful degradation: funciona con feeds parciales si uno falla
- **Documentación Threat Alert**: Agregada sección completa con verificación, comandos, troubleshooting
- **Integración en router-check**: Nueva verificación automática de estado del sistema de alertas

### v1.8.0 (2026-04-13)
- **Telegram Notifications Reorganizadas**: Sistema centralizado en grupo con prefijos temáticos
  - Cambio de chat privado (716542586) a grupo (Flint2 notifications)
  - Nueva función `send_telegram(msg, prefijo)` en config.sh
  - Todos los scripts ahora usan sistema de prefijos: [MWAN3], [BACKUP], [HEALTH], [SYSTEM], [WIFI]
  - Ejemplo anterior: sin prefijo, todo en chat privado
  - Ejemplo actual: `[SYSTEM] 📊 REPORTE DIARIO` en grupo compartido
  - Scripts actualizados:
    - failover_notify.sh: Prefijo [MWAN3] + duración downtime
    - backup_new.sh: Prefijo [BACKUP]
    - reporte_diario.sh: Cambio de notificar.sh → send_telegram() con prefijo [SYSTEM]
    - config_sync.sh: Agregó send_telegram() con prefijo [BACKUP]
  - Ventajas: Organización clara, fácil seguimiento por tema, mejor para documentación
- **MWAN3 Downtime Tracking**: Implementado seguimiento de duración de downtime
  - Guarda timestamps Unix en `/tmp/mwan3_down_wan` y `/tmp/mwan3_down_secondwan`
  - Calcula duración formateada (Xh Ym Zs o Ym Zs) cuando WAN se recupera
  - Mensaje de recuperación incluye: `Duración: 5m 23s`
- **Automatic Speedtest on WAN Recovery**: Nuevo script `speedtest_check.sh` integrado con failover_notify
  - Usa `/etc/script/speedtest` de Ookla (binario oficial, 2-3 minutos por test)
  - Se dispara automáticamente cuando WAN se recupera (delay 30s para estabilización)
  - Thresholds: Telmex/WAN 350 Mbps, Megacable/SecondWAN 210 Mbps
  - Mensaje incluye: Download speed, Ping, Duración, Estado (✅ OK / ⚠️ Bajo)
  - Ejemplo: `[MWAN3] 🟢 Speedtest - Telmex | 📥 1080.3Mbps (esperado: 350Mbps) | ⏱️ 2.7ms | ✅ OK`
  - Parsing JSON robusto con grep/awk (compatible ash/BusyBox)
  - Dependencia: `bc` instalado para cálculos de velocidad

### v1.7.0 (2026-04-13)
- **IoT DNS actualizado a NextDNS Anycast**: Cambio de DHCP option 6 de `1.1.1.1, 8.8.8.8` a `45.90.28.0, 45.90.30.0`
  - Alinea IoT VLAN con arquitectura DNS centralizada de NextDNS (perfil 47a69f)
  - Configuración: `/etc/config/dhcp` → `list dhcp_option '6,45.90.28.0,45.90.30.0'`
  - Fallback automático a segundo Anycast si primero no responde
- **Reglas DNAT del firewall eliminadas**: Removidas reglas de redirect IoT (UDP/TCP puerto 53)
  - Control de DNS ahora exclusivamente mediante DHCP option 6
  - Configuración más limpia, sin redundancia
- **AdGuard Home — IPv6 Deshabilitado**: Ahora escucha solo en IPv4
  - `bind_hosts`: Cambio de `0.0.0.0` (dual-stack) a `127.0.0.1` (IPv4 only)
  - `trusted_proxies`: Removida entrada `::1/128` (IPv6 localhost)
  - Puertos escuchando: `127.0.0.1:53` (DNS IPv4), `:::3000` (API/GUI IPv6)
  - DNS resolution funciona correctamente en IPv4
  - Configuración más segura y predecible

### v1.6.0 (2026-04-13)
- **DNS actualizado a NextDNS DoT**: Arquitectura simplificada
  - AGH:53 (puerto DNS) → Unbound:5335 (recursive) → NextDNS DoT fallback
  - Fallback directo a NextDNS anycast (45.90.28.0, 45.90.30.0)
  - CPE ID configurado para identificación centralizada
  - Sin dependencia de Tailscale
- **Notificaciones deshabilitadas**: Removidas alertas de WiFi flapping
  - onhostchange.sh: send_telegram para flapping comentada
  - /etc/hotplug.d/dhcp/97-notify: sin permisos de ejecución
- **Crontab simplificado**: Removidas 12+ tareas redundantes
  - master_daily.sh: reducido de 25 a 6 tareas esenciales
  - Tareas: mac_report, config_sync, log_cleaner, mwan3_test, wifi_report, reporte_diario
- **USB Auto-Mount & Post-Restore**: Nueva protección contra restauraciones
  - `/etc/init.d/usb-mount`: Monta USB automáticamente al arrancar
  - `/etc/script/post_restore.sh`: Restaura TODO desde USB después de sysupgrade
  - Redundancia en rc.local: Fallback si init.d falla
  - `/etc/script/config_sync.sh`: Backup diario 02:00 UTC al USB
  - Flujo automático: 5-10 minutos para recuperación completa
- **Backup mejorado**: backup_new.sh actualizado con Telegram OK
  - Copia directa (sin -u) para asegurar sobrescritura
  - 81 paquetes guardados automáticamente
  - Directorio completo de configuraciones copiado

### v1.5.0 (2026-04-11)
- **WiFi Clients Report by SSID**: Nuevo script `wifi_report.sh` para reportar clientes desglosados por SSID
  - ✅ Soporta **ambos routers automáticamente**:
    - Flint-2: Detecta interfaces `phy0-ap*`, `phy1-ap*` (60 clientes observados)
    - Beryl: Detecta interfaces `wlan*`, `wlan*-1` (16 clientes observados)
  - Auto-detecta formato de interfaz sin configuración manual
  - Modos: --live (dashboard 10s), --report (Telegram), --json (JSON), --summary (default)
  - Dashboard muestra: SSID, clientes por interfaz, MAC, RSSI, throughput esperado
  - Integrado en master_daily.sh a las 08:00 AM (ejecuta en ambos routers)
  - Reportes desglosados en Telegram mostrando clientes por red WiFi
- **Network Bandwidth Monitoring (nlbwmon)**: Agregado monitoreo completo con 5 puertos configurados
  - Interfaces monitoreadas: br-lan.10, br-lan.8, eth1 (WAN), lan1, tailscale0
  - Puertos: 631 (IPP), 139 (NetBIOS), 445 (SMB), 67 (DHCP-S), 68 (DHCP-C)
  - Excluido puerto 5335 (Unbound) — localhost-only, no es visible en interfaces
  - Alternativa recomendada: `unbound-control stats_noreset` para estadísticas DNS
- **DPI — Deep Packet Inspection**: Verificado y documentado netifyd + libndpi
  - netifyd 4.4.7 (aarch64, conntrack, netlink, dns-cache) ✅ OPERATIONAL
  - libndpi 5.0.0 (2.4MB) ✅ INSTALLED
  - CrowdSec ✅ ACTIVE
  - Capacidad: 35+ protocolos, 17,000+ aplicaciones identificables
  - Reportería automática: 08:00 AM diarios via Telegram
  - Caché: 385.5KB flow-hash, 62.7K DNS entries, 59-70% hit rate
- **Troubleshooting**: Documentadas razones por las que puerto 5335 no aparece en nlbwmon LuCI
- **Verificación**: Comandos para confirmar estado de nlbwmon, DPI y WiFi clients en tiempo real

### v1.4.0 (2026-04-10)
- **DNS Cache Intelligence**: Implementado sistema completo de caché inteligente (Phases 1-4)
  - Phase 1: Unbound optimizado a 192MB caché total, 4 threads
  - Phase 2: Warm-up de top 200 dominios cada 6h desde querylog
  - Phase 3: Persistencia de caché a USB cada 6h
  - Phase 4: Dashboard analytics (`--live` y `--report`)
- **Hit Rate**: Mejorado de 7.7% a 59-70%
- **Dashboard**: `/usr/bin/monitor/dns_smart_dashboard.sh` con top 10 dominios filtrados (nsroot.net, wpad)
- **Crons**: Agregados 3 jobs para warm-up, persist y reporte diario
- **Documentación**: Agregada sección completa sobre DNS Cache Intelligence

### v1.3.1 (2026-04-10)
- **AdGuard Home**: ⚠️ Intento de corrección de puerto a 3000 (no fue completamente aplicado al script)
- **Servicios**: Removido `usteerd` del chequeo (no instalado, no requerido)
- **WireGuard**: Actualizado a estado "Desinstalado" (removida verificación)
- **Tailscale tabla 52**: Documentado que tabla 52 puede estar vacía en modo exit-node-only (es normal)
- **Troubleshooting**: Agregadas secciones para diagnosticar tabla 52 vacía y conflictos con MWAN3

### v1.3.0 (2026-04-05)
- **Tailscale Exit Node**: Configurado como exit node (anuncia 0.0.0.0/0), iPhone puede usarlo para salida a internet
- **Firewall Forward Rules**: Agregada regla `forward_tailscale` para permitir tráfico tailscale0 → WAN (wan/eth1, lan1)
- **Masquerade Rules**: Reglas nftables para traducir IPs de Tailscale en salida (persistidas en `/etc/firewall.user`)
- **DNS Resilience**: Configurado Unbound con upstreams estáticos (Google 8.8.8.8, Cloudflare 1.1.1.1)
- **DNS No Tailscale Dependent**: DNS ahora funciona sin dependencia de Tailscale (antes: Tailscale controlaba resolv.conf)
- **Backup**: Generado backup con toda la configuración incluyendo Unbound, Firewall, Tailscale, AdGuard Home

### v1.2.0 (2026-04-04)
- **WireGuard**: Desinstalado de Flint-2 — removidas verificaciones de wg0 y puerto 51820
- **AdGuard Home**: Puerto actualizado de 3000 a 3053 (cambio de configuración)
- **Tailscale**: Reiniciado y confirmado operativo (daemon `tailscaled` activo)
- **Servicios**: Actualizado monitoreo para usar `tailscaled` en lugar de `tailscale`, `usteerd` confirmado correcto
- **Tabla 52**: Confirmada poblada con 3 rutas (Tailscale funcionando correctamente)
- Todos los servicios críticos verificados y operativos ✅

### v1.1.0 (2026-04-03)
- Agregados checks de CPU y load average
- Agregada verificación de delay aleatorio en `monitor_sistema.sh` (evita falsas alertas de CPU)
- Agregado conteo de scripts en minuto 0 (detecta contención de cron)
- Documentado problema conocido de alertas de CPU falsas por contención de cron

### v1.20.0 (2026-05-24 22:30+)
- **WiFi Hotplug Tracker Beryl**: Actualización y corrección de configuración
  - Beryl: Corregida topología de 2→5 interfaces activas (phy0-ap0, phy0-ap2, phy1-ap0, wlan0-1, wlan1-1)
  - Watchdog: Actualizado EXPECTED de 2→5 procesos en `wifi_client_tracker_watchdog_beryl.sh`
  - Handler: Agregados 5 interface mappings completos (phy*-ap* + wlan*)
  - **Telegram Token Beryl**: Actualizado a `REDACTED_BOT_TOKEN` ✅
  - Service: Verificado que inicia 5 procesos en ambos routers (Flint-2 idéntico a Beryl)
  - ✅ Sistema Beryl ahora operativo (5/5 procesos activos, alerts listos)

### v1.19.0 (2026-05-24)
- **WiFi Hotplug Tracker**: Sistema event-driven captura AP-STA-CONNECTED/DISCONNECTED eventos en tiempo real
  - Handler simplificado (`onhostchange.sh`) con phy*-ap* interface support
  - Telegram alerts instantáneas con hostname, SSID, IP, MAC, bitrate/signal
  - 5 procesos hostapd_cli activos (uno per interfaz WiFi)
  - Persistencia en sysupgrade.conf
  - Log en `/var/log/wifi_client_tracker.log`
  - ✅ Ambos eventos (CONNECT + DISCONNECT) capturados y operativos

### v1.0.0
- Versión inicial con checks de servicios, MWAN3, Tailscale, WireGuard, AdGuard Home, temperatura, RAM, disco, WiFi
