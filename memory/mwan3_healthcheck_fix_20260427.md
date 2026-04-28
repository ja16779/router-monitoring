---
name: MWAN3 Healthcheck Fix — Ajuste de Reliability (2026-04-27)
description: Corrección de healthcheck ping que fallaba por reliability agresivo
type: project
originSessionId: ae67fc42-954c-48f8-b197-a95f80c1176f
---
## Problema Identificado

El cambio inicial de `reliability=1/3` era **demasiado agresivo** combinado con quality checks estrictos (180ms latencia, 10% pérdida), causando:
- Pérdida de paquetes del 50% a OpenDNS
- Interface secondwan marcada como "disconnecting"
- Fallos intermitentes en healthcheck ping

**Log de error:**
```
user.info mwan3track: Check (ping: latency=18ms loss=50%) failed for target "208.67.220.220"
user.info mwan3track: Lost 2 ping(s) on interface secondwan
user.notice mwan3track: Stopping mwan3track for interface "wan". Status was "online"
```

---

## Correcciones Aplicadas

### 1. Reliability ajustado a valores más sensatos
| Parámetro | Antes | Después | Razón |
|-----------|-------|---------|-------|
| wan | 1/3 (33%) | **2/3 (66%)** | Necesita 2 de 3 pings exitosos |
| secondwan | 1/3 (33%) | **2/2 (100%)** | Mantiene exigencia pero coherente |

**Impacto:** Reduce falsos positivos mientras mantiene detección rápida de fallos.

### 2. Quality checks normalizados
| Parámetro | Antes | Después | Razón |
|-----------|-------|---------|-------|
| failure_latency | 180ms | **250ms** | Menos sensible a lag temporal |
| failure_loss | 10% | **15%** | Tolera variación normal de fibra |
| recovery_latency | 100ms | **150ms** | Recuperación menos exigente |
| recovery_loss | 2% | **5%** | Más realista para fibra |

**Impacto:** Menos falsos positivos, pero sigue detectando problemas reales.

### 3. Count sincronizado
| Parámetro | Antes | Después | Razón |
|-----------|-------|---------|-------|
| secondwan count | 3 | **2** | Coincide con reliability 2/2 |

**Lógica:** Si reliability=2/2 necesita 2 éxitos, count=2 es suficiente.

### 4. Script de alertas corregido
**Problema:** Script fallaba en cron (exit errors)
**Solución:**
- Cambiar de `uci get` a `mwan3 status` (más confiable)
- Mejorar manejo de errores
- Agregar fallback silencioso si notificar.sh no existe
- Log local de cambios en `/tmp/mwan3_alerts/mwan3_changes.log`

**Resultado:** Script ahora se ejecuta sin errores.

---

## Estado Verificado ✅

```
Interface status:
 interface wan is online and tracking is active (online 00h:00m:21s)
 interface secondwan is online and tracking is active (online 00h:00m:21s)

Current ipv4 policies:
 balanced: secondwan (37%), wan (62%)
```

- ✅ Healthcheck ping funcionando
- ✅ Ambas interfaces tracking activo
- ✅ Balance correcto 62/38
- ✅ Script de alertas sin errores

---

## Configuración Final

### Health Check Parameters
| Parámetro | WAN | SECONDWAN | Significado |
|-----------|-----|-----------|------------|
| Reliability | 2/3 | 2/2 | Éxitos requeridos de intentos |
| Count | 3 | 2 | Intentos de ping |
| Interval | 10s | 10s | Chequeo cada 10 segundos |
| Timeout | 6s | 6s | Máximo por ping |
| Failure Latency | — | 250ms | Umbral de latencia mala |
| Failure Loss | — | 15% | Umbral de pérdida mala |

### Tracking IPs
- **wan:** 208.67.222.222 (OpenDNS), 1.1.1.1 (Cloudflare)
- **secondwan:** 8.8.8.8 (Google), 1.1.1.1 (Cloudflare)

---

## Lecciones Aprendidas

### ❌ No hacer
- `reliability=1/N`: Demasiado sensible, muchos falsos positivos
- Quality checks ultrastrictos (180ms) en fibra variable
- Cambios muy agresivos sin testing incremental

### ✅ Hacer
- `reliability=2/3 o 2/2`: Balance entre sensibilidad y estabilidad
- Quality checks con margen (250ms latencia, 15% pérdida)
- Diversificar tracking IPs (OpenDNS + Google + Cloudflare)
- Testear cambios antes de producción

---

## Timeline de esta sesión

| Hora | Acción | Estado |
|------|--------|--------|
| 13:00 | Aplicar FASE 1+2 (reliability=1/3) | ❌ Falló: ping errors |
| 13:01 | Script alertas con errores | ❌ Cron errors |
| 13:02 | Ajustar reliability a 2/3 | ✅ Funciona |
| 13:02 | Arreglar script alertas | ✅ Sin errores |
| 13:03 | Verificación final | ✅ TODO OK |

---

## FASE 2 Final (Corregida)

✅ **Interval:** 10s (-50% CPU) — MANTENER
✅ **Tracking IPs:** Diversificadas — MANTENER
✅ **Sticky timeouts:** 180-300s — MANTENER
✅ **Reliability:** 2/3, 2/2 — CORREGIDO
✅ **Quality checks:** 250ms, 15% — CORREGIDO
✅ **Alertas:** Script funcional — CORREGIDO

---

## Próximas mejoras (FASE 3 - opcional)

- [ ] Monitorear latencia real por 1 semana
- [ ] Ajustar quality thresholds si hay variabilidad
- [ ] Dashboard Grafana para visualizar cambios de WAN
- [ ] Agregar más tracking IPs locales (DNS México)
