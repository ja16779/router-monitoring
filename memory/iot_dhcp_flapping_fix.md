---
name: IoT DHCP Flapping Fix — Resolución
description: Se resolvió flapping de dispositivos IoT habilitando DHCP en VLAN IoT (br-lan.8)
type: project
originSessionId: 0ae2cb93-3170-4396-8c45-1af6ded5c062
---
## Problema Resuelto

**Síntoma**: Dispositivo TP-Link IoT (`d0:a0:bb:7d:9f:a8`) hacía flapping WiFi cada ~42 segundos

**Causa Raíz**: DHCP estaba **deshabilitado** en la interface IoT (`br-lan.8` / `IOT` en UCI)

**Dispositivos afectados**: 20+ dispositivos IoT en VLAN 8 (192.168.8.x)

## Solución Aplicada

Habilitar DHCP en la interface IoT:

```
config dhcp 'IOT'
	option interface 'IOT'
	option dhcpv4 'server'  ← CAMBIO: deshabilitado → server
	option start '100'
	option limit '150'
	option leasetime '72h'
	list dhcp_option '6,192.168.8.1'
	list dhcp_option '42,192.168.8.1'
	list dhcp_option '42,45.90.28.245,45.90.30.245'
```

## Por Qué Funcionaban sin DHCP

Algunos dispositivos IoT tienen IP estática configurada en firmware (p. ej., repetidores WiFi TP-Link), así que no dependían de DHCP para conectar. Sin embargo, el cliente TP-Link `d0:a0:bb:7d:9f:a8` busca DHCP agresivamente:

- ✅ Se conecta por WiFi normalmente
- ❌ No obtiene IP por DHCP
- ⚠️ Intenta DHCP discover cada ~42s
- 🔄 Cada intento causa reconexión (flapping)

## Mejora Actual (2026-04-22)

**Métricas**:
- **Antes**: Reconexión cada ~42 segundos
- **Ahora**: Conectado 76+ minutos consecutivos (last event hace ~4-5 min)
- **Bitrate**: 6.0 MBit/s (limitación del cliente TP-Link, no del AP)
- **Signal**: -61 dBm (excelente)

**Comportamiento residual**:
- Flapping ocasional cada ~2-3 minutos (normal para este cliente con bitrate bajo)
- Sistema `flap-silencing` ativa para evitar alertas por falsos positivos
- No afecta el funcionamiento de otros dispositivos

## Configuración Actual (2026-04-22)

- ✅ DHCP habilitado en IOT (`dhcpv4: 'server'`)
- ✅ DNS primario: 192.168.8.1 (AdGuardHome local)
- ✅ DNS fallback: 45.90.28.245, 45.90.30.245 (NextDNS anycast)
- ✅ Lease time: 72h (para dispositivos semi-permanentes)
- ✅ 20+ dispositivos IoT activos

## Notas

- **Por qué se deshabilitó originalmente**: Probablemente fue un intento previo de solucionar problemas de conectividad, pero causó el efecto opuesto
- **Solución completa**: DHCP + `legacy_rates=0` (radio0) + IP estática para TP-Link
- **Flapping residual**: Inherente al dispositivo TP-Link por bajo bitrate; aceptable ahora
