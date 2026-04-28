---
name: RE220 Offline Incident — Resolución Final (2026-04-23)
description: RE220 repetidor offline — diagnóstico y doble solución (script + DHCP estático). Dispositivo actualmente desconectado; configuración lista para cuando se reconecte.
type: project
originSessionId: c94e4099-5998-4017-89c7-e56420c55c6c
---
# RE220 Offline Incident — Resolución Final

## Incidente Original (2026-04-22)

**Problema**: Monitor RE220 marcaba dispositivo como OFFLINE permanentemente
**Causa**: Script verificaba IP `192.168.8.150` pero DHCP asignaba dinámicamente `192.168.8.107`

## Soluciones Implementadas (2026-04-23)

### ✅ Opción 1: Script Update (Quick Fix)
- **Archivo**: `/usr/bin/monitor/re220_monitor.sh`
- **Cambio**: IP variable actualizada `192.168.8.107` → `192.168.8.150`
- **Estado**: COMPLETADO (2026-04-23 11:34 UTC)

### ✅ Opción 2: DHCP Estático (Permanent Fix)
- **Configuración UCI**: 
  ```
  dhcp.@host[0]=host
  dhcp.@host[0].name='RE220'
  dhcp.@host[0].mac='b6:09:21:69:5d:8d'
  dhcp.@host[0].ip='192.168.8.150'
  ```
- **Ubicación**: Flint-2 `/etc/config/dhcp` (verificado 2026-04-23)
- **Persistencia**: Guardado vía `uci commit`

## Estado Actual (2026-04-23 11:43 UTC)

| Aspecto | Status |
|---------|--------|
| **Dispositivo RE220** | 🔴 OFFLINE (no conectado) |
| **DHCP Reserva** | ✅ Configurada para 192.168.8.150 |
| **Script Monitor** | ✅ Actualizado para 192.168.8.150 |
| **Logs** | ✅ Reporta correctamente OFFLINE |
| **Telegram Notificación** | ✅ Listo para enviar (cuando se reconecte) |

## Diagrama de Flujo

```
RE220 DESCONECTADO
    ↓
Usuario enciende RE220
    ↓
RE220 intenta conectar a red 192.168.8.x
    ↓
Solicita lease DHCP
    ↓
dnsmasq asigna 192.168.8.150 (según configuración estática)
    ↓
Monitor script (cada 5 min) ejecuta: ping -c 2 -W 3 192.168.8.150
    ↓
Ping responde → ONLINE ✅
    ↓
Script envía: 🟢 RE220 ONLINE (Telegram)
```

## Verificación

### Configuración DHCP (Flint-2, verificado 2026-04-23)
```bash
uci show dhcp | grep -A 5 host
# Salida esperada:
# dhcp.@host[0]=host
# dhcp.@host[0].name='RE220'
# dhcp.@host[0].mac='b6:09:21:69:5d:8d'
# dhcp.@host[0].ip='192.168.8.150'
```

### Script Monitor (verificado 2026-04-23)
```bash
head -10 /usr/bin/monitor/re220_monitor.sh | grep RE220_IP
# Salida esperada:
# RE220_IP="192.168.8.150"
```

### Ejecución Manual
```bash
bash /usr/bin/monitor/re220_monitor.sh
logread | grep -i re220 | tail -5
# Salida esperada si offline:
# Thu Apr 23 11:43:41 2026 user.notice re220-monitor: state=offline
```

## Próximos Pasos

1. **Cuando RE220 se conecte**:
   - Buscará IP vía DHCP en rango 192.168.8.100-249
   - Obtendrá 192.168.8.150 (reserva configurada)
   - Cron ejecuta monitor cada 5 min
   - Ping a 192.168.8.150 responde ✅
   - Estado cambia offline → **online**
   - Telegram recibe: 🟢 **RE220 ONLINE**

2. **Validación**:
   ```bash
   # Desde Flint-2
   ping -c 2 -W 2 192.168.8.150
   # Debe responder si RE220 está conectado
   
   # Ver IP asignada
   udhcpc -R 192.168.8.150  # en cliente, para renovar
   ```

## Notas Técnicas

- **MAC Address RE220**: `b6:09:21:69:5d:8d`
- **VLAN IoT**: `br-lan.8` (rango DHCP 192.168.8.100-249)
- **Cron Monitor**: `*/5 * * * *` (cada 5 minutos)
- **Timeout ping**: `3 segundos`
- **Telegram**: Notificaciones activas para cambios de estado

## Diferencia: Quick Fix vs Permanent Fix

| Aspecto | Quick Fix | Permanent Fix |
|---------|-----------|---------------|
| **Cambio** | Script solo | DHCP configurado |
| **IP Futura** | Aún 192.168.8.107 (aleatorio) | Siempre 192.168.8.150 |
| **Durabilidad** | Temporal (IP puede cambiar) | Persistente (garantiza misma IP) |
| **Usado** | ✅ Sí (mientras DHCP no configure reserva) | ✅ Sí (cuando RE220 se reconecte) |

**Decisión**: Ambas soluciones aplicadas → máxima robustez
