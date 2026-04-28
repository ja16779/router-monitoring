---
name: DNS Actual — Arquitectura Verificada 2026-04-17
description: Configuración DNS REAL en Flint-2 (2026-04-17): AGH:53, Unbound:5335, IoT bypass, dnsmasq solo DHCP
type: project
originSessionId: 3ab63c79-a102-4073-9eb2-7c72eb994852
---
## Arquitectura DNS ACTUAL (2026-04-17) — VERIFICADA

```
LAN/WiFi clientes
   ↓ DHCP option 6: 192.168.10.1
AdGuardHome:53  (filtrado, caché, upstream DoT)
   ↓ upstream DoT
tls://47a69f.dns.nextdns.io  (NextDNS, perfil 47a69f)
   ↓ fallback anycast
45.90.28.0 / 45.90.30.0  (NextDNS bootstrap)

Unbound:5335  (caché recursivo, independiente)
   ↓ (no usado por AGH)
(disponible para clientes que lo consulten directamente)

IoT clientes (br-lan.8)
   ↓ bypass completo de AGH
NextDNS Anycast directo  (sin filtros AGH)
45.90.28.0 / 45.90.30.0  (configurado en DHCP option 6 IoT)

dnsmasq
   ├─ Función: DHCP server ONLY (port=0, sin DNS)
   ├─ DHCP LAN: 192.168.10.100-250
   ├─ DHCP IoT: 192.168.8.100-249
   └─ NO hace forward DNS (port=0 desactiva DNS)
```

## Configuración AdGuardHome

**Puerto DNS**: 53 (escucha en 192.168.10.1:53)

**Upstream**: `tls://47a69f.dns.nextdns.io` (DoT)

**Bootstrap**: `45.90.28.0`, `45.90.30.0` (NextDNS anycast)

**Clientes LAN**: Via DHCP option 6 → `192.168.10.1:53`

**Estadísticas**: Disponibles en http://192.168.10.1:3000/

## Configuración Unbound:5335

**Función**: Caché recursivo independiente (disponible si clientes lo especifican)

**Puerto**: 5335 (TCP/UDP)

**Status**: Activo pero no usado directamente por AGH

**Caso de uso**: Alternativa manual para clientes si AGH se cae

## Configuración dnsmasq

**Configuración UCI** (`/etc/config/dhcp`):
```
option port='0'  # DHCP ONLY, DNS desactivado
```

**Función**:
- DHCP server para LAN (br-lan.10)
- DHCP server para IoT (br-lan.8)
- NO hace resolución DNS

## IoT VLAN (br-lan.8)

**DHCP**: 192.168.8.100-249

**DHCP option 6** (DNS servers): `45.90.28.0`, `45.90.30.0`

**Resultado**: IoT clientes consultan directamente a NextDNS anycast, sin pasar por AGH

**Ventaja**: IoT apps no filtradas por AGH (útil si algún app requiere acceso a sitios bloqueados)

## Verificación (2026-04-17)

✅ AGH respondiendo en :53
✅ Unbound activo en :5335
✅ NextDNS quota monitor: 116,742 / 300,000 queries (38%)
✅ DNS resolution: OK
✅ IoT bypass: ACTIVO

## Notas

1. **Unbound vs AGH**: AGH es el punto principal de entrada (filtrado). Unbound es backup/alternativa.
2. **IoT deliberado**: El bypass de IoT a NextDNS es intencional (no pasar por AGH).
3. **dnsmasq**: Solo DHCP, no interfiere con DNS.
4. **Puerto 53**: AGH escucha aquí, dnsmasq no compite (port=0).
5. **Fallback**: Si AGH se cae, clientes LAN se quedarían sin DNS. Unbound es alternativa manual.

## Diferencias con anterior documentación (dns_architecture_dot.md)

| Aspecto | Anterior (2026-04-13) | Actual (2026-04-17) |
|---------|----------------------|----------------------|
| **AGH puerto** | 3053 | **53** |
| **dnsmasq función** | DNS + DHCP | **DHCP ONLY** (port=0) |
| **Unbound** | Removido (2026-04-12) | **ACTIVO en 5335** |
| **IoT DNS** | Via nftables DNAT | **Via DHCP option 6** |
| **LAN DNS** | Via dnsmasq → AGH | **Via DHCP option 6 → AGH:53** |

**Conclusión**: La arquitectura es más simple de lo documentado. AGH es DNS principal, Unbound es backup, dnsmasq es DHCP puro.
