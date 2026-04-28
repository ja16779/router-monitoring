---
name: Beryl Offline Incident — 2026-04-22
description: Beryl se quedó sin responder, reinicio de ambos routers resolvió el problema
type: project
originSessionId: 54a3a44d-4277-46f7-a70f-b8acddc7d2f7
---
## Incidente: Beryl No Respondía (2026-04-22)

**Fecha**: 2026-04-22 ~17:40 UTC
**Usuario**: ja16779
**Acción**: Reinicio de Flint-2 y Beryl

### Síntomas
- Beryl (192.168.10.2) no respondía a SSH
- Ping a 192.168.10.2 → 100% packet loss
- Beryl no estaba en tabla ARP de Flint-2
- No tenía lease DHCP activo

### Diagnóstico Realizado
1. Intentó SSH a Beryl → **timeout**
2. Desde Flint-2, verificó:
   - Ping a Beryl → **sin respuesta**
   - Tabla ARP → Beryl **no listado**
   - DHCP leases → Beryl **sin lease**
   - Logs de Flint-2 → sin intentos recientes de Beryl

### Solución Aplicada
Reinicio de ambos routers (usuario)

### Resultado Post-Reinicio
- Flint-2: ✅ 100% operativo
  - Todos servicios running
  - Ambas WANs online (Telmex + Megacable)
  - Tailscale exit node funcionando
  - DNS resolviendo correctamente
  - Hardware: 50°C, RAM OK, CPU bajo
  
- Beryl: ✅ 100% operativo
  - Uptime: 18 minutos post-reinicio
  - SSH respondiendo
  - dnsmasq + dropbear running
  - IP: 192.168.10.2/24 (DHCP OK)
  - Conectividad a Flint-2: ✅

### Causa Probable
- Beryl se "colgó" (hung process) — necesitaba power cycle
- Posibles razones: agotamiento de memoria, servicio congelado, problema de red

**Why**: Beryl no reinicia automáticamente solo. Depende del usuario para poder-cycle físico.

**How to apply**: Implementar watchdog remoto o monitoreo de Beryl desde Flint-2 para detectar no-respuesta y alertar al usuario. Alternativa: script que alerte si Beryl no responde por X minutos consecutivos.

## Monitoreo Recomendado
- Agregar check de ping a Beryl en cron (cada 5-10 min)
- Telegram alert si Beryl no responde > 2 veces consecutivas
- Dashboard mostrando uptime/status de Beryl en tiempo real
