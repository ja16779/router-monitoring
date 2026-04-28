---
name: Dashboard Unbound completado
description: Dashboard inteligente de Unbound - Phase 4 completa (--live y --report con cron)
type: project
originSessionId: 1c8accd5-11c4-4d9c-9396-667fbef1aee6
---
## Dashboard Inteligente de DNS — ✅ Phases 1-4 Completadas

### Fase 4: Dashboard Analytics (2026-04-10)

**Archivo creado**: `/usr/bin/monitor/dns_smart_dashboard.sh`

#### Modo `--live` (Terminal Interactiva)
```bash
dns_smart_dashboard.sh --live
```

Interfaz en tiempo real que se refresca cada 30s:
- **Hit Rate**: Porcentaje de aciertos (código de color: verde >60%, amarillo >30%, rojo <30%)
- **Estadísticas de Consultas**: Total, hits, misses, prefetch, SERVFAIL errors
- **Estado del Caché**: Tamaño MB, cantidad de registros, persistencia (última actualización del dump)
- **Rendimiento**: RTT promedio, memoria en uso, uptime del servicio
- **Top 10 Dominios**: Dominios más consultados del querylog de AdGuard (con conteos)

#### Modo `--report` (Telegram Diario)
```bash
dns_smart_dashboard.sh --report
```

Envía reporte consolidado vía Telegram con:
- Timestamp y métricas consolidadas
- Hit rate, queries totales, tamaño caché, latencia
- Uptime y memoria
- Top 5 dominios consultados (con links al dashboard --live)
- Formato Markdown para buena legibilidad

### Integración en Cron

```
53 22 * * * /usr/bin/monitor/dns_smart_dashboard.sh --report
```

Se ejecuta diariamente a las 22:53 UTC (16:53 CST/México).

**Horario elegido**:
- Minuto 53 (evita congestión de minutos 0/30)
- 22:53 UTC = 16:53 CST (media tarde en México, resumen completo del día)

### Resumen de Phases 1-4

| Phase | Componente | Archivo | Propósito | Status |
|-------|-----------|---------|-----------|--------|
| 1 | Optimización Unbound | `/var/lib/unbound/unbound.conf` | Cache 192MB total (64MB + 128MB) | ✅ |
| 2 | Warm-up | `/usr/bin/monitor/dns_warmup.sh` | Pre-carga top 200 dominios cada 6h | ✅ |
| 3 | Persistencia | `/usr/bin/monitor/dns_cache_persist.sh` | Persiste/restaura caché entre reinicios | ✅ |
| 4 | Dashboard | `/usr/bin/monitor/dns_smart_dashboard.sh` | Analytics con --live y --report diario | ✅ |

### Crontabs Configuradas

```
0 */6 * * * /usr/bin/monitor/dns_warmup.sh              # Precarga
0 */6 * * * /usr/bin/monitor/dns_cache_persist.sh save  # Persiste
53 22 * * * /usr/bin/monitor/dns_smart_dashboard.sh --report  # Reporte diario
```

### Funciones Helper Implementadas

- `get_unbound_stats()` - Extrae estadísticas vía unbound-control
- `calculate_hit_rate()` - Calcula hit % = (hits / queries) * 100
- `get_top_domains()` - Parsea querylog JSON de AdGuard
- `get_cache_stats()` - Tamaño en MB y cantidad de registros
- `get_uptime()` - Dias, horas desde boot del servicio
- `get_memory_usage()` - RSS en MB o KB según magnitud
- `get_rtt_average()` - Latencia promedio a nameservers
- `show_live_dashboard()` - Loop 30s con refresh de terminal
- `send_report()` - Formatea y envía a Telegram via curl

### Métricas Esperadas

Según plan original (before/after):
- Hit rate: 7.7% → 40-60% (con warm-up + caché 192MB + persist)
- Latencia dominios populares: ~104ms → <10ms
- Pérdida de caché en reinicio: 100% → ~5% (via Redis/dump)
- RAM en caché: ~6MB → ~192MB

**Validación**: Ejecutar `dns_smart_dashboard.sh --live` para verificar hit rate en tiempo real.

### Estado - OPERATIVO ✅
- ✅ Script instalado en /usr/bin/monitor/dns_smart_dashboard.sh
- ✅ Modo --live operativo (compatible con BusyBox/ash)
  - Actualiza pantalla cada 30 segundos
  - Muestra hit rate, estadísticas, caché, rendimiento, top dominios
  - Probado y validado en Flint-2
- ✅ Modo --report configurado para Telegram
- ✅ Cron job agregado (ejecución diaria 22:53 UTC)
- ✅ Integración con sistema de monitoreo completa

### Fixes Realizados
1. **Problema: `clear` incompatible con ash** → Solución: Reemplazado con `printf '\n'` (30 líneas)
2. **Problema: Estadísticas sin prefijo thread** → Solución: Agregación con `awk` de todos los threads (thread0., thread1., etc.)
3. **Problema: `ps aux` no existe en BusyBox** → Solución: Usando `ps w` (compatible)
4. **Problema: Caracteres especiales causaban errores** → Solución: Removidos caracteres especiales, usando [*] [-] en lugar de emojis
