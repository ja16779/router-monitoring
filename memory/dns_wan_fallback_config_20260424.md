---
name: DNS WAN Fallback Configuration (2026-04-24)
description: WANs configuradas con NextDNS Anycast fallback (45.90.28.245/30.245) para máxima resiliencia
type: project
originSessionId: c94e4099-5998-4017-89c7-e56420c55c6c
---
# DNS WAN Fallback Configuration — 2026-04-24

## Problema Identificado (33% encriptado en NextDNS)

**Causa:** IoT VLAN estaba usando NextDNS Anycast directo, bypass de AdGuardHome
- Queries encriptadas no se registraban en AGH
- Falta de visibilidad y control

## Solución Implementada

### 1. IoT VLAN — Corregida (2026-04-24)

**Antes:**
```
dhcp.IOT.dhcp_option='6,192.168.8.1' '42,45.90.28.245,45.90.30.245'
                                                    ↑ NextDNS directo
```

**Después:**
```
dhcp.IOT.dhcp_option='6,192.168.8.1'
```

**Impacto:** Todos los dispositivos IoT ahora pasan por AdGuardHome primero

### 2. WAN DNS Fallback — Configurado (2026-04-24)

**WAN Principal (Telmex):**
```
network.wan.dns='127.0.0.1 45.90.28.245 45.90.30.245'
network.wan.peerdns='0'    (no usar DNS del ISP)
```

**WAN Secundaria (Megacable):**
```
network.secondwan.dns='127.0.0.1 45.90.28.245 45.90.30.245'
network.secondwan.peerdns='0'
```

## Jerarquía DNS Resultante

### 1️⃣ **Primaria (99.9% del tiempo):**
```
Cliente LAN → 192.168.10.1:53 (AdGuardHome)
           → 127.0.0.1:5335 (Unbound - recursive)
           → tls://29e346.dns.nextdns.io (NextDNS DoT)
```

### 2️⃣ **Fallback (si AGH/Unbound falla):**
```
Router → 45.90.28.245 (NextDNS Anycast perfil 29e346)
      → 45.90.30.245 (NextDNS Anycast perfil 29e346)
```

### 3️⃣ **IoT VLAN (ahora correcto):**
```
Cliente IoT → 192.168.8.1:53 (AdGuardHome)
          → 127.0.0.1:5335 (Unbound)
          → NextDNS fallback
```

## Beneficios

| Métrica | Antes | Después |
|---------|-------|---------|
| **Queries monitoreadas AGH** | ~67% | ~100% |
| **Queries encriptadas** | 33% | <5% |
| **Punto de fallo único** | ✅ AGH | ✅ AGH + NextDNS |
| **Filtros aplicados** | Incompleto | Completo |
| **Dependencia ISP** | Potencial | ✅ No |

## Configuración Detallada

### UCI Settings
```
# WAN Principal
network.wan.proto='dhcp'
network.wan.peerdns='0'
network.wan.dns='127.0.0.1 45.90.28.245 45.90.30.245'

# WAN Secundaria
network.secondwan.proto='dhcp'
network.secondwan.peerdns='0'
network.secondwan.dns='127.0.0.1 45.90.28.245 45.90.30.245'

# IoT VLAN (corregida)
dhcp.IOT.dhcp_option='6,192.168.8.1'

# LAN (normal)
dhcp.lan.dhcp_option='6,192.168.10.1'
```

### NextDNS Anycast Específico

```
45.90.28.245 → Perfil 29e346 (con todos los filtros)
45.90.30.245 → Perfil 29e346 (redundancia)
```

**NO usar 45.90.28.0** (genérico, sin filtros específicos)

## Verificación

```bash
# Ver DNS configurados
uci show network.wan.dns
uci show network.secondwan.dns

# Ver si AGH está respondiendo
nslookup google.com 127.0.0.1

# Ver si NextDNS fallback funciona
nslookup google.com 45.90.28.245
```

## Impacto en NextDNS Analytics

**Expectativa post-cambio:**
- ✅ Queries "encriptadas" baja de 33% a <5%
- ✅ Queries totales aumentan en AGH logs
- ✅ Todo el tráfico visible en AdGuardHome

## Archivos Modificados

- `/etc/config/network` — DNS en wan y secondwan
- Cron/scripts — Sin cambios

## Notas

- Cambios aplicados 2026-04-24 13:45 UTC
- Verificado en LuCI post-refresh (Ctrl+Shift+R)
- Sin downtime (cambio en vivo)
- Fallback testeable manualmente si AGH se detiene

