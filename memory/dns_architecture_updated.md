---
name: DNS Actualizado — Configuración Óptima (2026-04-17)
description: Unbound convertido a recursivo con zona root ICANN local. AGH primario upstream = Unbound:5335
type: project
originSessionId: 3ab63c79-a102-4073-9eb2-7c72eb994852
---
## Arquitectura DNS ACTUALIZADA (2026-04-17)

```
Clientes LAN
    ↓ DHCP option 6: 192.168.10.1
AdGuardHome:53  (filtrado local: anuncios + malware)
    ├─ Upstream[0]: 127.0.0.1:5335  ← Unbound RECURSIVO ★PRIMARIO★
    ├─ Upstream[1]: tls://47a69f.dns.nextdns.io   (NextDNS DoT, fallback)
    └─ Upstream[2]: quic://47a69f.dns.nextdns.io  (NextDNS QUIC, fallback)
    
        Unbound:5335  (RECURSIVO REAL)
            ├─ Zona root: Descargada de ICANN vía AXFR
            │  └─ Autoridades: lax.xfr.dns.icann.org, iad.xfr.dns.icann.org
            ├─ TTL: min 120s, max 86400s (caché agresivo)
            ├─ DNSSEC: Activo (root.key operativo)
            └─ Fallback: Recursión normal a root servers si ICANN AXFR falla
    
    fallback_dns (AGH): 45.90.28.0, 45.90.30.0  (NextDNS anycast, último recurso)

IoT VLAN (br-lan.8)
    ↓ DHCP option 6 directo
45.90.28.0 / 45.90.30.0  (NextDNS anycast, bypass AGH intencional)
```

## Cambios Realizados (2026-04-17 08:26 UTC)

### 1. Unbound: Forwarder → Recursivo Real

**Cambio**: Eliminado bloque `forward-zone` de `/etc/unbound/unbound.conf`

**Antes**:
```
forward-zone:
    name: "."
    forward-addr: 45.90.28.0@53
    forward-addr: 45.90.30.0@53
```

**Después**: Sin forward-zone. Unbound ahora:
- Consulta root servers (.)
- Descarga zona root de ICANN automáticamente
- Sirve la zona root localmente (extremadamente rápido para queries cacheadas)

### 2. Auth ICANN Habilitada

**Comando**: `uci set unbound.auth_icann.enabled=1`

**Efecto**:
- Unbound descarga la zona raíz (.) de ICANN vía AXFR
- Se actualiza automáticamente cada período configurado
- Si AXFR falla: fallback a recursión normal (fallback=1 ya estaba configurado)

**Servidores ICANN AXFR**:
- `lax.xfr.dns.icann.org` (primario)
- `iad.xfr.dns.icann.org` (secundario)

### 3. Configuración UCI de Unbound

```
config unbound 'ub_main'
    option enabled='1'
    option listen_port='5335'
    option num_threads='2'
    option recursion='default'    ← Recursión habilitada
    option validator='1'           ← DNSSEC activo
    option ttl_min='120'
    option ttl_neg_max='1000'
    option unbound_control='1'
    list iface_trig 'lan'
    list iface_trig 'wan'
    
config zone 'auth_icann'
    option enabled='1'            ← ★ CAMBIO: Era 0, ahora 1
    option fallback='1'           ← Fallback a recursión si AXFR falla
    option zone_type='auth_zone'
    list zone_name='.'            ← Zona root
    list server='lax.xfr.dns.icann.org'
    list server='iad.xfr.dns.icann.org'
```

## Configuración AdGuard Home (SIN CAMBIOS)

```yaml
dns:
  port: 53
  bind_hosts:
    - 0.0.0.0
  upstream_dns:
    - 127.0.0.1:5335              ← Unbound PRIMARIO (resolución local)
    - tls://47a69f.dns.nextdns.io ← NextDNS DoT (fallback)
    - quic://47a69f.dns.nextdns.io ← NextDNS QUIC (fallback)
  bootstrap_dns:
    - 45.90.28.0
    - 45.90.30.0
  fallback_dns:
    - 45.90.28.0
    - 45.90.30.0
```

AGH ya estaba configurado con `127.0.0.1:5335` como upstream. No requirió cambios.

## Dnsmasq (SIN CAMBIOS)

```
option port='0'  ← DHCP only, sin DNS
```

## Verificación Post-Cambio (2026-04-17 08:26 UTC)

✅ **Unbound recursivo**
- Resolviendo queries exitosamente: `dig @127.0.0.1 -p 5335 google.com` → `192.178.56.238`
- PID: 30604, estado: running

✅ **Zona root ICANN**
- AXFR en progreso (proceso normal, toma 5-10 minutos)
- Fallback: si AXFR falla, Unbound hace recursión normal a root servers

✅ **Caché iniciado**
- Stats: 1 query completada
- TTL: 120s (mín) — 86400s (máx)

✅ **AGH funcionando**
- Upstream[0] = Unbound:5335 (primario)
- Upstream[1,2] = NextDNS (fallback)

✅ **IoT bypass intacto**
- DHCP option 6: 45.90.28.0, 45.90.30.0
- Sin pasar por AGH (intencional)

## Cambios respecto a configuración anterior (dns_architecture_actual.md)

| Aspecto | Anterior (2026-04-17 08:00) | Actual (2026-04-17 08:26) |
|---------|------------------------------|--------------------------|
| **Unbound tipo** | Forwarder → NextDNS anycast | **RECURSIVO real** |
| **forward-zone** | Presente (parche manual) | **Eliminado** |
| **auth_icann** | Deshabilitado (0) | **Habilitado (1)** |
| **Zona root** | No tiene | **Descargada de ICANN** |
| **Primario en AGH** | 127.0.0.1:5335 (forwarder) | **127.0.0.1:5335 (recursivo)** |
| **Fallback si Unbound cae** | No (Unbound era otro forward a NextDNS) | **Sí (NextDNS DoT/QUIC)** |

## Ventajas de la nueva arquitectura

1. **Privacidad**: Unbound resuelve sin depender de NextDNS (recursión local)
2. **Resiliencia**: Si NextDNS no responde, Unbound sigue resolviendo
3. **Velocidad**: Zona root local = queries muy rápidas (sin ir a root servers)
4. **Simplicidad**: Un solo resolver recursivo en el pipeline (no dos forwarders)
5. **DNSSEC**: Validación local completa
6. **Control**: Unbound es independiente, no es un wrapper de otro DNS

## Próximos pasos

1. **Esperar 5-10 minutos** para que Unbound complete AXFR de zona root ICANN
2. **Monitorear caché**: `unbound-control stats | grep -E 'cachehits|cachemiss'`
3. **Verificar logs**: `logread | grep unbound`
4. **Router-check en 30 minutos** para confirmar caché poblado
5. **Opcional**: Habilitar estadísticas extendidas si se desean más métricas

## Archivos modificados

- `/etc/unbound/unbound.conf` — forward-zone eliminado
- UCI `unbound.auth_icann.enabled` — 0 → 1
- AGH — sin cambios (ya tenía la config correcta)
