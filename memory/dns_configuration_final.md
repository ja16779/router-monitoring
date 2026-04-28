---
name: DNS Final — Configuración Completada (2026-04-17)
description: Unbound recursivo con ICANN AXFR operativo, validator_ntp=0 para habilitar auth-zones
type: project
originSessionId: 3ab63c79-a102-4073-9eb2-7c72eb994852
---
## Estado Final DNS (2026-04-17 10:52 UTC)

### Arquitectura
```
Clientes LAN
    ↓ DHCP option 6: 192.168.10.1
AdGuardHome:53 (filtrado, DoT/QUIC upstream)
    ├─ upstream[0]: 127.0.0.1:5335 (Unbound recursivo + ICANN AXFR)
    ├─ upstream[1]: tls://47a69f.dns.nextdns.io (NextDNS DoT)
    └─ upstream[2]: quic://47a69f.dns.nextdns.io (NextDNS QUIC)
    
        Unbound:5335 (RECURSIVO CON ICANN AXFR)
            ├─ Zona root (2.1 MB) descargada de ICANN
            ├─ Zona arpa (35.4 KB)
            ├─ Zona in-addr.arpa (215.8 KB)
            ├─ Fallback: recursión normal si AXFR falla
            └─ TTL: min 120s, max 72000s
```

### Configuración UCI Unbound
```
uci.unbound.ub_main:
  - enabled='1'
  - listen_port='5335'
  - num_threads='2' (aumentado a 4 en unbound_srv.conf)
  - rate_limit='1000' (fue 20)
  - validator_ntp='0' ← KEY FIX (permite AXFR en boot)
  - recursion='default'
  
uci.unbound.auth_icann:
  - enabled='1'
  - fallback='1'
  - zone_type='auth_zone'
  - zone_name='.' 'arpa.' 'in-addr.arpa.'
  - server='lax.xfr.dns.icann.org' 'iad.xfr.dns.icann.org'
  - url_dir='https://www.internic.net/domain/'
```

### Configuración AdGuardHome
```yaml
dns:
  port: 53
  upstream_dns:
    - 127.0.0.1:5335 ← Unbound (primario)
    - tls://47a69f.dns.nextdns.io ← NextDNS DoT (fallback)
    - quic://47a69f.dns.nextdns.io ← NextDNS QUIC (fallback)
  upstream_mode: load_balance
  fastest_timeout: 3s
  upstream_timeout: 5s
  fallback_dns:
    - 45.90.28.0
    - 45.90.30.0 (NextDNS anycast)
  bootstrap_dns:
    - 45.90.28.0
    - 45.90.30.0
  cache_size: 134217728 (128MB)
  cache_ttl_min: 3600 (1h)
  cache_ttl_max: 86400 (24h)
  cache_optimistic: true
```

## Problema Encontrado y Solucionado

### Síntoma
- Auth-zones configuradas en UCI pero NO aparecían en /var/lib/unbound/unbound.conf
- Unbound se reiniciaba intermitentemente
- AGH mostraba errores "connection refused" para Unbound

### Causa Raíz
El script de Unbound (`/usr/lib/unbound/unbound.sh`) requiere:
```bash
if [ $UB_B_NTP_BOOT -eq 0 ] && [ -n "$UB_LIST_ZONE_NAMES" ] ...
```

Pero `UB_B_NTP_BOOT` viene de `validator_ntp`, que por defecto es 1 (habilitado):
```bash
config_get_bool UB_B_NTP_BOOT "$cfg" validator_ntp 1
```

Con `validator_ntp=1` → `UB_B_NTP_BOOT=1` → auth-zones NO se generan

### Solución
```bash
uci set unbound.ub_main.validator_ntp=0
uci commit unbound
/etc/init.d/unbound restart
```

### Resultado Post-Fix
✅ Auth-zones apareció en unbound.conf (3 zonas)
✅ Archivos de zona descargados (2.1 MB root.zone)
✅ DNS resolución operativa: google.com → 192.178.56.238
✅ Cache estadísticas: thread0/1 resolviendo, cachehits empezando

## Archivos Modificados
- `/etc/config/unbound` — validator_ntp: 1 → 0
- `/var/lib/unbound/unbound.conf` — regenerado con auth-zone sections
- `/var/lib/unbound/*.zone` — descargados automáticamente

## Próximos Pasos
1. Monitorear caché hit rate en 30 minutos (debería ser 30-50% después de población)
2. Verificar estadísticas con: `unbound-control stats_noreset`
3. Revisar logs cada 12h para confirmar AXFR automático desde ICANN

## Ventajas de Configuración Final
1. **Recursión local**: Unbound resuelve sin depender continuamente de NextDNS
2. **Zona root local**: Queries a root servers = 0 (todo servido desde caché local)
3. **Fallback real**: Si NextDNS cae, Unbound puede resolver usando root servers descargados
4. **DNSSEC**: Validación local completa con root.key de ICANN
5. **Privacy**: Primarios queries van a Unbound (recursivo), no a NextDNS
6. **Performance**: Zona root en caché = respuestas muy rápidas para SOA/NS queries
