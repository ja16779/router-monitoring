---
name: Unbound DNS Dashboard — Completado (2026-04-27)
description: Dashboard HTML con Top 10 dominios y clientes, datos desde AdGuardHome API, auto-instalación en sysupgrade
type: project
originSessionId: ae67fc42-954c-48f8-b197-a95f80c1176f
---
## Dashboard Completado ✅

**URL:** `http://192.168.10.1/unbound-dashboard/`

### Características

#### Estadísticas principales
- Total de queries (acumulativo desde reinicio de Unbound)
- Cache hits / misses (desde Unbound stats)
- Hit rate % (hits / total)
- Uptime del router (desde boot)
- Unbound status (uptime desde último reinicio + fecha exacta)

#### Top 10 Dominios
- Extrae desde AdGuardHome API (`/control/stats`)
- Muestra dominio y contador de queries
- Actualización cada minuto

#### Top 10 Clientes
- Extrae desde AdGuardHome API
- Muestra IP del cliente y total de queries
- Tabla interactiva

#### Gráfico de rendimiento
- Visualización proporcional de hits vs misses
- Canvas HTML5

### Configuración

| Componente | Ubicación | Descripción |
|------------|-----------|------------|
| **HTML** | `/www/unbound-dashboard/index.html` | Dashboard interfaz (responsive) |
| **JSON** | `/www/unbound-dashboard/stats.json` | Datos en tiempo real |
| **Script** | `/usr/bin/monitor/unbound_dashboard_update.sh` | Actualiza datos cada minuto |
| **Cron** | `* * * * *` | Ejecuta el script cada minuto |
| **Log** | `/var/log/unbound_dashboard.log` | Logs de actualizaciones |
| **Auto-install** | `/etc/uci-defaults/99-unbound-dashboard` | Se reinstala tras sysupgrade |

### API Utilizada

- **AdGuardHome API:** `http://127.0.0.1:3000/control/stats`
  - `top_queried_domains`: Top dominios consultados
  - `top_clients`: Top clientes (IPs)
  - Procesa con `jq` para extraer y limitar a 10 registros

### Script de Actualización

**Versión:** v3 (Corregido)
**Key fix:** Usar `unbound-control stats_noreset` (NO resetear contadores)
**Field fix:** `total.num.cachemiss` (singular, no "misses")
**Timeout:** Sin timeout (rápido, ~1 segundo)
**Dependencias:** `curl`, `jq`, `unbound-control`

```bash
# Extrae datos de Unbound con stats_noreset
# Procesa con jq: 
#   - top_queried_domains[0:10]
#   - top_clients[0:10]
# Escribe JSON combinado en stats.json
```

### Actualización del Dashboard

- **Auto-refresh:** Cada 30 segundos (JavaScript)
- **Data update:** Cada minuto (cron script)
- Formatea números con separadores (ej: 27,931)
- Tablas interactivas con hover effect
- Responsive design (funciona en móvil/desktop)

### Persistencia

**En caso de sysupgrade:**
- ✅ Auto-instalación mediante `/etc/uci-defaults/99-unbound-dashboard`
- ✅ Script se reinstala automáticamente
- ✅ Cron se reconfigura automáticamente
- ✅ HTML se restaura automáticamente

**En caso de reinicio normal:**
- ✅ Todo se mantiene intacto
- ✅ Contadores continúan acumulando

**En caso de reinicio de Unbound:**
- ❌ Contadores se resetean (están en RAM)
- ✅ Dashboard sigue funcionando desde cero

### Acceso

**Opción 1: Página de inicio (Recomendado)**
```
http://192.168.10.1/
```
Muestra 3 botones: LuCI Configuration, All Dashboards, Unbound DNS Dashboard

**Opción 2: Portal de dashboards**
```
http://192.168.10.1/dashboards.html
```
Panel dedicado con acceso a todos los dashboards

**Opción 3: Dashboard directo**
```
http://192.168.10.1/unbound-dashboard/
```
Ir directo al dashboard de DNS

### Problemas Solucionados

1. **Puerto 8953 en uso** → Crear `/var/run/unbound/` con permisos correctos
2. **Stats se reseteaban** → Usar `stats_noreset` en lugar de `stats`
3. **Campo incorrecto** → Cambiar de `cachemisses` a `cachemiss` (singular)
4. **Query logging causaba crasheos** → Desactivar query logging, mantener syslog simple

### Datos de Ejemplo

```json
{
  "timestamp": "2026-04-27T23:56:56Z",
  "total_queries": 50,
  "cache_hits": 15,
  "cache_misses": 35,
  "hit_rate": 30,
  "router_uptime": "up 4 days, 23:26, load average: 0.01, 0.07",
  "unbound_uptime": "0d 2h 30m",
  "unbound_start_time": "2026-04-27 17:53:43",
  "top_domains": {
    "data": [
      {"domain": "m2.tuyacn.com", "count": 27931},
      {"domain": "a.root-servers.net", "count": 17465},
      ...
    ]
  },
  "top_clients": {
    "data": [
      {"client": "192.168.8.104", "queries": 19474},
      {"client": "192.168.8.150", "queries": 17482},
      ...
    ]
  }
}
```

### Próximas mejoras (opcional)

- [ ] Gráfico de tendencias por hora
- [ ] Export CSV de top dominios
- [ ] Alertas si dominio malicioso en top 10
- [ ] Histórico de cambios de clientes (base de datos)
- [ ] Integración LuCI como tab

---

## Estado Final ✅

✅ Dashboard HTML completado
✅ Top 10 dominios mostrado (desde AdGuardHome)
✅ Top 10 clientes mostrado (desde AdGuardHome)
✅ Auto-actualización funcionando (30s navegador, 1min script)
✅ Cron configurado (cada minuto)
✅ Accesible en puerto 80
✅ Auto-instalación en sysupgrade
✅ Contadores acumulativos desde reinicio de Unbound
✅ Router Status vs Unbound Status diferenciado
