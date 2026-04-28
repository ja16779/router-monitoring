---
name: WiFi Analyzer — Monitoreo automático de interferencia (Opción A)
description: wifi_analyzer.sh configurado en crontab para análisis cada 12h + alertas Telegram. Sin cambios automáticos (manual review). Activado 2026-04-19
type: project
originSessionId: continued-b6dfda45-a2d0-479a-ac75-92b80d73bbbe
---

## Configuración Completada ✅

**Fecha**: 2026-04-19 ~21:45 UTC  
**Router**: Flint-2 (GL-MT6000)  
**Script**: `/usr/bin/monitor/wifi_analyzer.sh`  
**Modo**: Análisis + Notificación Telegram (sin cambios automáticos)

---

## Crontab Configurado

| Hora | Frecuencia | Comando | Log |
|------|-----------|---------|-----|
| **03:00 UTC** | Diario | `wifi_analyzer.sh notify` | `/var/log/wifi_analyzer.log` |
| **15:00 UTC** | Diario | `wifi_analyzer.sh notify` | `/var/log/wifi_analyzer.log` |

**Intervalo**: Cada 12 horas

---

## Qué hace wifi_analyzer.sh

### Análisis
✅ **2.4GHz**: Escanea canales 1, 6, 11 (no solapados)  
✅ **5GHz**: Escanea canales 36, 40, 44, 48, 149, 153, 157, 161  
✅ **Vecinos**: Cuenta redes detectadas por canal  
✅ **Score**: Calcula interferencia de cada canal  

### Decisión (Opción A)
❌ **NO cambia automáticamente**  
✅ **SÍ alerta vía Telegram** con análisis + recomendación  
✅ Requiere **review manual** antes de cambiar  

### Output Telegram

```
📡 WiFi Channel Analysis — Flint-2

2.4GHz (radio0) — Canal Actual: 1
├─ Canal 1:  Score 2 (OK - pocas redes)
├─ Canal 6:  Score 4 ⚠️ (Más interferencia)
├─ Canal 11: Score 1 ✅ (Mejor opción)
└─ Recomendación: Canal 1 es aceptable

5GHz (radio1) — Canal Actual: 44
├─ Canal 36:  Score 1 ✅
├─ Canal 44:  Score 0 (Excelente)
├─ Canal 149: Score 1 ✅
└─ Recomendación: Canal 44 OK
```

---

## Escenario de Uso

### Caso 1: Sin interferencia
```
✅ "Canales actuales óptimos, sin cambios recomendados"
Próximo chequeo: 15:00 UTC
```

### Caso 2: Interferencia detectada
```
⚠️ "2.4GHz: Canal 1 degradado (Score 8). 
    Vecinos en canal 1-6 detectados.
    Opción: Cambiar a Canal 11 (Score 1)"
    
Acción manual requerida:
uci set wireless.radio0.channel='11'
uci commit wireless
wifi reload
```

---

## Historia de Cambio

**Antes**:
- No había monitoreo de interferencia WiFi
- Sin alertas de canales congestionados

**Después**:
- ✅ Análisis automático cada 12 horas
- ✅ Alertas Telegram si se detecta degradación
- ✅ Recomendaciones de canales alternativos
- ✅ Log centralizado en `/var/log/wifi_analyzer.log`
- ✅ Requiere manual review (seguro para router principal)

---

## Canales Monitoreados

### 2.4GHz (Flint-2 actual: Canal 1)
| Canal | Frecuencia | Potencia | Estado |
|-------|-----------|----------|--------|
| 1 | 2.412 GHz | 20 dBm | ✅ Actual |
| 6 | 2.437 GHz | 20 dBm | Alternativa |
| 11 | 2.462 GHz | 20 dBm | Alternativa |

### 5GHz (Flint-2 actual: Canal 44)
| Canal | Frecuencia | Potencia | DFS | Estado |
|-------|-----------|----------|-----|--------|
| 36 | 5.180 GHz | 17 dBm | No | Alternativa |
| 40 | 5.200 GHz | 17 dBm | No | Alternativa |
| **44** | **5.220 GHz** | **17 dBm** | Sí | ✅ Actual |
| 48 | 5.240 GHz | 17 dBm | Sí | Alternativa |
| 149 | 5.745 GHz | 26 dBm | No | Ocupado por Beryl |
| 153 | 5.765 GHz | 26 dBm | No | Alternativa |
| 157 | 5.785 GHz | 26 dBm | No | Alternativa |
| 161 | 5.805 GHz | 26 dBm | No | Alternativa |

---

## Separación de Canales (Flint-2 vs Beryl)

| Router | 2.4GHz | 5GHz | Interferencia |
|--------|--------|------|----------------|
| **Flint-2** | Canal 1 | Canal 44 (DFS) | Mínima ✅ |
| **Beryl** | Canal 6 | Canal 149 (no-DFS) | Separados |

**Validación**: wifi_analyzer monitorea ambos y alerta si aparecen conflictos.

---

## Próximas Ejecuciones Automáticas

- ⏭️ **Próxima**: 2026-04-20 03:00 UTC (3am)
- ⏭️ **Siguiente**: 2026-04-20 15:00 UTC (3pm)
- 📋 Log se creará en: `/var/log/wifi_analyzer.log`

---

## Verificación Manual (Opcional)

Si quieres ejecutar antes de la próxima cron:

```sh
# Análisis sin notificación
/usr/bin/monitor/wifi_analyzer.sh

# Análisis + alerta Telegram
/usr/bin/monitor/wifi_analyzer.sh notify

# Verbose (debug)
/usr/bin/monitor/wifi_analyzer.sh -v notify
```

---

## Notas

- **Opción A (elegida)**: Análisis + alertas, sin cambios automáticos
- **Seguridad**: Requiere review manual antes de cambiar canal (evita disruptions)
- **Router principal**: Cambios manuales es lo apropiado para Flint-2
- **Beryl AP**: Si el usuario quisiera, podría tener versión `auto` más tarde
- **Telegram**: Alerts se envían al chat ID configurado en `/etc/monitor/config.sh`

---

## Comparativa de Scripts WiFi

| Script | Función | Estado |
|--------|---------|--------|
| `wifi_analyzer.sh` | Análisis + alertas + recomendaciones | ✅ ACTIVO (Opción A) |
| `wifi_channel_monitor.sh` (v1) | Auto-cambio 2.4GHz simple | (disponible, no activo) |
| `wifi_channel_monitor_v2.sh` | Auto-cambio 2.4GHz+5GHz avanzado | (disponible, no activo) |
| `wifi_report.sh` | Reporte de clientes por SSID | ✅ Activo (diario 08:00) |
