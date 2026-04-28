---
name: Master Scripts - Timeout Protection Implementation
description: Implementación de protección de timeout en todos los master scripts para prevenir bloqueos
type: project
originSessionId: ae67fc42-954c-48f8-b197-a95f80c1176f
---
## Correcciones Realizadas (2026-04-27)

### Problemas Identificados
1. **master_realtime.sh** (16 tareas, cada 60 segundos)
   - Sin protección de timeout
   - Tareas pueden colgarse indefinidamente
   - Bloquearía ejecución de todas las tareas posteriores
   - Una tarea deshabilitada (crowdsec) en comentario

2. **master_hourly.sh** (5 tareas, cada 3600 segundos)
   - Sin protección de timeout
   - Vulnerable a bloqueos de larga duración

3. **master_daily.sh** (6 tareas, ejecución diaria)
   - Sin timeout en función run_task()
   - Tareas pueden ejecutarse indefinidamente

4. **master_weekly.sh** (9 tareas condicionales)
   - Sin protección de timeout
   - Tareas largas (speedtest, iperf) sin límite de tiempo

5. **master_5min.sh** (huérfano)
   - Archivo existía pero no estaba en crontab
   - Sus tareas eran redundantes con master_realtime.sh
   - **Eliminado completamente**

### Correcciones Aplicadas

#### 1. Timeout Protection agregado a todos los masters:

| Master Script | Timeout | Justificación |
|---------------|---------|---------------|
| master_realtime.sh | 300s (5 min) | Ejecuta cada 60s, timeout máximo 5 min |
| master_hourly.sh | 600s (10 min) | Ejecuta cada 3600s, timeout máximo 10 min |
| master_daily.sh | 1800s (30 min) | Ejecuta diariamente, timeout máximo 30 min |
| master_weekly.sh | 2700s (45 min) | Tareas largas (speedtest/iperf), máximo 45 min |

#### 2. Implementación técnica:

Cambio en `run_if_interval()` y `run_task()`:
```bash
# Antes:
if sh -c "$cmd" >> "$LOG_FILE" 2>&1; then

# Después:
if timeout $TIMEOUT_REALTIME sh -c "$cmd" >> "$LOG_FILE" 2>&1; then
    ...
else
    local exit_code=$?
    if [ $exit_code -eq 124 ]; then
        log_msg "ERROR" "$name: TIMEOUT (${TIMEOUT_REALTIME}s exceeded)"
    else
        log_msg "ERROR" "$name: Falló (exit: $exit_code)"
    fi
fi
```

#### 3. Limpieza:

- Removidas tareas deshabilitadas (crowdsec) de comentarios
- Eliminado master_5min.sh (huérfano y redundante)
- Mantenidas todas las tareas activas

### Validación

✓ Todos los 4 master scripts tienen protección de timeout
✓ master_5min.sh eliminado (no estaba en cron)
✓ Logs mejorados para distinguir entre TIMEOUT y ERROR real
✓ Timeout escalado según frecuencia de ejecución (crítico para realtime)

### Impacto Esperado

- **Antes**: Una tarea colgada bloqueaba indefinidamente todas las posteriores
- **Después**: Timeout protege contra ejecuciones largas:
  - realtime: máximo 5 min de retardo en próxima ejecución (cada 60s)
  - hourly: máximo 10 min de retardo en próxima ejecución (cada 3600s)
  - daily/weekly: máximo 30-45 min de retardo

### Archivos Modificados
- `/usr/bin/monitor/master_realtime.sh` ✓
- `/usr/bin/monitor/master_hourly.sh` ✓
- `/usr/bin/monitor/master_daily.sh` ✓
- `/usr/bin/monitor/master_weekly.sh` ✓

### Archivos Eliminados
- `/usr/bin/monitor/master_5min.sh` ✗ (huérfano)
