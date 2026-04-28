---
name: Monitor Master Meta-Monitor Instalado
description: Monitor central que consolida todos los scripts de monitoreo en una sola entrada cron
type: project
---

## Instalación completada y verificada: 2026-04-07

**monitor_master.sh** reemplaza las múltiples entradas `*/5 * * * *` con un único meta-monitor central.

### Configuración actual

- **Archivo**: `/usr/bin/monitor/monitor_master.sh`
- **Entrada cron**: `*/5 * * * * /usr/bin/monitor/monitor_master.sh`
- **Estado**: ✅ Instalado, verificado y 100% operacional
- **Log central**: `/var/log/monitor_master.log`
- **Directorio de estado**: `/tmp/monitor_state/`

### Prueba de validación: ✅ ÉXITO COMPLETO
- **14/14 scripts ejecutándose sin errores**
- Tiempo total ejecución: ~42 segundos
- Todos los timestamps registrados correctamente
- Logs centralizados funcionando

### Ventajas vs modelo anterior

| Métrica | Antes | Ahora |
|---------|-------|-------|
| Contención CPU | ~10 procesos en minuto 0, picos 80%+ | 1 proceso distribuido, sin picos |
| Entradas cron | 14+ líneas | 1 línea |
| Logging | Disperso en logread | Centralizado: `/var/log/monitor_master.log` |
| Control | Difícil parar/pausar múltiples scripts | 1 punto central |

### Scripts consolidados (14 total)

**Cada 60 segundos (1 minuto)**:
- presencia.sh

**Cada 300 segundos (5 minutos)**:
- monitor_internet.sh
- monitor_servicios.sh
- monitor_sistema.sh
- wa850_monitor.sh
- new_device_alert.sh
- re220_monitor.sh
- crowdsec_notify.sh
- healthcheck_ping.sh
- beryl_monitor.sh

**Cada 600 segundos (10 minutos)**:
- temp_alert.sh
- adguard_health.sh ✅ (error de sintaxis fue corregido el 2026-04-07)

**Cada 900 segundos (15 minutos)**:
- monitor_red.sh
- dhcp_pool_monitor.sh

### Errores solucionados

**adguard_health.sh** tenía un error de sintaxis (if/fi mal anidado, línea 49: "unexpected else"). Fue corregido el 2026-04-07. El problema era que faltaba un `fi` para cerrar correctamente el bloque condicional interno.

### Verificación

- ✅ Script instalado y ejecutable
- ✅ Cron activo y corriendo
- ✅ Todos los 14 scripts presentes
- ✅ Logs centralizados funcionando
- ✅ Timestamps de ejecución almacenados en `/tmp/monitor_state/`

### Cómo monitorear

```bash
# Ver logs en tiempo real
tail -f /var/log/monitor_master.log

# Verificar timestamps de última ejecución
ls -la /tmp/monitor_state/

# Manual: ejecutar meta-monitor
/usr/bin/monitor/monitor_master.sh
```

### Reversión (si es necesario)

Backup guardado en: `/etc/crontabs/root.backup`

Para revertir, restaurar las entradas antiguas desde el backup y eliminar monitor_master de cron.
