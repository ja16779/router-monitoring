# OpenWrt Router Monitoring & Management

Colección de scripts, configuraciones y herramientas para monitoreo y gestión de routers OpenWrt (Flint-2 GL-MT6000 y Beryl GL-MT3000).

## 📁 Estructura

### `/memory`
Documentación detallada de configuraciones, optimizaciones y proyectos completados:
- **Unbound Dashboard** — Dashboard HTML con estadísticas de DNS en tiempo real
- **MWAN3 Configuration** — Dual-WAN setup (Telmex + Megacable)
- **Master Scripts** — Consolidación de 38 scripts en 4 maestros (realtime, hourly, daily, weekly)
- **DNS Optimization** — Arquitectura DNS optimizada con latencia sub-milisegundo
- **WiFi & Network** — Optimizaciones de WiFi, RPS/RFS, roaming detection
- **Threat Detection** — Sistema de detección de amenazas con C2 blocking

### `/skills`
Scripts y herramientas especializadas:
- **router-check** — Health check completo de routers via SSH (Python/Paramiko)
  - Verifica servicios críticos
  - MWAN3 status
  - DNS infrastructure (AdGuard Home, Unbound, Dashboard)
  - Hardware metrics (temp, RAM, disk, load)
  - Conectividad

## 🚀 Uso

### Health Check de Routers
```bash
python3 skills/router-check/router-check.py
```

Salida esperada:
- ✅ Verificación de servicios
- ✅ Estado de WANs
- ✅ Dashboard de Unbound
- ✅ Temperatura y recursos

## 📊 Proyectos Principales

### Unbound Dashboard
URL: `http://192.168.10.1/unbound-dashboard/`

**Características:**
- Top 10 dominios consultados (desde AdGuardHome API)
- Top 10 clientes (IPs) por queries
- Cache hits/misses acumulativos
- Hit rate %
- Uptime de router y Unbound
- Auto-refresh cada 30 segundos
- Auto-instalación en sysupgrade

**Técnica:**
- Script de actualización: `/usr/bin/monitor/unbound_dashboard_update.sh`
- Cron: Cada minuto
- Datos: `/www/unbound-dashboard/stats.json`
- API: AdGuardHome `http://127.0.0.1:3000/control/stats`

### MWAN3 Dual-WAN
**WANs:**
- `wan` (Telmex): 350Mbps, prioritario para DNS/Tailscale
- `secondwan` (Megacable): 210Mbps, fallback

**Health Checks:**
- Reliability: 2/3 (Telmex), 2/2 (Megacable)
- Interval: 10 segundos (-50% CPU)
- Quality checks: 250ms latencia, 15% pérdida
- Tracking IPs: OpenDNS, Google, Cloudflare

**Failover:**
- Detección automática en ~15 segundos
- Sticky sessions para estabilidad
- Alertas Telegram en cambios

### Master Scripts (4 especializados)
| Script | Frecuencia | Timeout | Tareas |
|--------|-----------|---------|--------|
| `master_realtime.sh` | 60s | 300s | 16 (críticas) |
| `master_hourly.sh` | 3600s | 600s | 5 (indexing) |
| `master_daily.sh` | Diario | 1800s | 6 (cleanup) |
| `master_weekly.sh` | Semanal | 2700s | 9 (tests) |

Todas con **timeout protection** para evitar bloqueos indefinidos.

### DNS Optimization
**Latencia:** 170ms → 0.24ms (-99.8%)

**Stack:**
```
Clientes (puerto 53)
    ↓
AdGuardHome (puerto 53)
    ↓
Unbound (puerto 5335) — Recursivo con auth-zones
    ↓
NextDNS Ultralow DoH (IP 200.25.32.197)
```

**Optimizaciones:**
- Cache persistence en USB
- Warm-up de 500 dominios
- Compresión querylog (gzip)
- RPS/RFS multi-core enabled
- 60% hit rate post-reinicio

## 🔧 Configuración Base

**Flint-2 (GL-MT6000):**
```
- CPU: MediaTek MT7988A (4 cores)
- RAM: 4GB
- Almacenamiento: 512MB flash
- Interfaces: 1 WAN, 2 LAN, WiFi 6
```

**Beryl (GL-MT3000):**
```
- CPU: MediaTek MT7981 (2 cores)
- RAM: 2GB
- Almacenamiento: 128MB flash
- Interfaces: 1 WAN, 1 LAN, WiFi 5 (repetidor)
```

**OpenWrt:** Versión 25.12.2

## 📚 Documentación

Cada archivo en `/memory` contiene:
- **Descripción:** Qué se implementó y por qué
- **Configuración:** Parámetros específicos
- **Estado:** Verificación de funcionamiento
- **Troubleshooting:** Problemas conocidos y soluciones

## 🔐 Seguridad

- Threat Alert System: 387 IPs C2 bloqueadas
- Anomaly detection
- Alertas Telegram en tiempo real
- DoT/DoH con validación DNSSEC

## 📝 Notas

- Todos los scripts están optimizados para ash/BusyBox (limitaciones OpenWrt)
- Persistencia en sysupgrade mediante `/etc/uci-defaults/`
- Logging en `/var/log/` con rotación automática
- Monitoreo via Telegram en grupo "Flint2 notifications"

---

**Última actualización:** 2026-04-27
**Autor:** ja16779
