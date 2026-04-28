---
name: Threat Alert System MVP — Completado
description: Sistema OpenWrt de detección de amenazas instalado y operacional. Bloquea 387 IPs C2, detecta anomalías de red, envía alertas a Telegram.
type: project
originSessionId: 5df9b90a-0dee-4075-a28c-7433d3d62640
---
# Threat Alert System — MVP Completado (2026-04-14)

**Estado:** ✅ PRODUCCIÓN — Instalado en Flint-2, Operacional 24/7

---

## Componentes Instalados

| Archivo | Líneas | Función | Estado |
|---------|--------|---------|--------|
| `threat_feed_updater.sh` | 240 | Descarga feeds de amenazas | ✅ Cron @00:00, @12:00 |
| `anomaly_detector.sh` | 190 | Detecta anomalías de red | ✅ Cron @*/5 minutos |
| `security_monitor.sh` | 300 | Dashboard en tiempo real | ✅ 3 modos (--check, --live, --alert) |
| `config.sh` | 102 | Configuración (Telegram, umbrales) | ✅ Con credenciales |

**Ubicación en router:**
- Scripts: `/usr/local/lib/threat-alert/`
- Symlinks: `/usr/local/bin/`
- Config: `/etc/threat-alert/config.sh`
- Logs: `/var/log/threat-alert/`
- Feeds: `/etc/threat-alert/feeds/`

---

## Feeds de Amenazas

### Emerging Threats C2 IPs
- **Cantidad:** 387 servidores bloqueados
- **Fuente:** https://rules.emergingthreats.net/blockrules/compromised-ips.txt
- **Actualización:** Automática cada 12 horas (00:00 y 12:00 UTC)
- **Archivo:** `/etc/threat-alert/feeds/emerging_c2_ips.txt` (5.4KB)
- **Status:** ✅ Descargado exitosamente

### URLhaus Malware Domains
- **Status:** ⚠️ Bloqueado por ISP (Telmex)
- **Fallback:** Sistema funciona sin este feed (graceful degradation)
- **Motivo del bloqueo:** ISP bloquea abuse.ch en nivel DPI

---

## Detección de Anomalías

Sistema detecta automáticamente cada 5 minutos:

1. **Port Scanning**
   - Threshold: > 20 puertos únicos por dispositivo en 5 min
   - Alerta: Notificación a Telegram

2. **SSH Brute Force**
   - Threshold: > 5 intentos fallidos en 5 min
   - Alerta: Notificación a Telegram

3. **DNS Flooding**
   - Threshold: > 100 queries en 10 segundos
   - Alerta: Notificación a Telegram

4. **Firewall Block Anomalies**
   - Detecta surges anómalos en bloqueos
   - Alerta: Notificación a Telegram

---

## Threat Level Score (0-100)

**Algoritmo de cálculo:**
- Firewall blocks > 50: +30 pts
- Firewall blocks > 100: +30 pts adicionales
- SSH attempts > 5: +20 pts
- SSH attempts > 20: +30 pts adicionales
- Connections > 100: +10 pts
- Connections > 200: +20 pts adicionales

**Niveles:**
- 0-19: 🟢 NORMAL (sin amenaza)
- 20-49: 🟡 SOSPECHOSO (actividad anómala)
- 50+: 🔴 CRÍTICO (posible ataque)

---

## Comandos Disponibles

```bash
# Ver nivel de amenaza actual (instantáneo)
/usr/local/lib/threat-alert/security_monitor.sh --check

# Dashboard en vivo (actualiza cada 5 segundos)
/usr/local/lib/threat-alert/security_monitor.sh --live

# Enviar alerta de prueba a Telegram
/usr/local/lib/threat-alert/security_monitor.sh --alert

# Actualizar feeds manualmente
/usr/local/lib/threat-alert/threat_feed_updater.sh

# Monitorear bloqueos en tiempo real (cada 10 segundos)
/usr/local/bin/monitor_c2_blocks.sh
```

---

## Archivos Críticos

| Archivo | Función |
|---------|---------|
| `/usr/local/lib/threat-alert/config.sh` | Token Telegram, umbrales, etc. |
| `/etc/threat-alert/feeds/emerging_c2_ips.txt` | Lista actual de 387 IPs C2 |
| `/var/log/threat-alert/updater.log` | Logs de actualización de feeds |
| `/var/log/threat-alert/anomaly.log` | Logs de anomalías detectadas |

---

## Cron Jobs Configurados

```
0 */12 * * * /usr/local/lib/threat-alert/threat_feed_updater.sh >> /var/log/threat-alert/updater.log 2>&1
*/5 * * * * /usr/local/lib/threat-alert/anomaly_detector.sh >> /var/log/threat-alert/anomaly.log 2>&1
```

**Horarios:**
- Feed update: 00:00 UTC (medianoche) y 12:00 UTC (mediodía)
- Anomaly detection: Cada 5 minutos

---

## Alertas Telegram

Sistema envía automáticamente:
- 🔐 Feed update notifications (cada 12 horas)
- 🔴 Port Scanning detected
- ⚠️ SSH Brute Force detected
- 🌊 DNS Flooding detected
- 📊 Firewall Block Anomaly detected
- 🔔 Alertas de prueba (manual)

---

## Estado Actual (2026-04-14 21:04)

```
✅ System: OPERATIONAL
✅ Threat Feeds: 387 C2 IPs bloqueadas
✅ Anomaly Detection: Activo (cron @*/5)
✅ Feed Updates: Automático (@00:00, @12:00 UTC)
✅ Telegram Alerts: Configuradas
✅ Security Monitor: Respondiendo

Current Threat Level: 🟢 NORMAL (0/100)
Firewall blocks: 0
SSH attempts: 0
Active connections: 12+
```

---

## Documentación

### En GitHub (cuando se publique)
- README.md: Instrucciones de instalación
- ROADMAP.md: Plan de fases futuras (VLAN isolation, LuCI dashboard, ML detection)
- CONTRIBUTING.md: Guía para contribuyentes
- DEPLOYMENT.md: Notas de instalación actual

### En Skill router-check
- Versión actualizada a 1.9.0
- Nueva sección "Threat Alert System — C2 IP Blocking"
- Comandos de verificación y troubleshooting

---

## Fase Futura (Phase 2)

Planeado pero no implementado:
- [ ] Device isolation en VLAN 99
- [ ] LuCI web dashboard
- [ ] Integración CrowdSec
- [ ] Machine learning anomaly detection
- [ ] Community threat database

---

## Notas Operativas

1. **Resiliencia:** Sistema funciona incluso si un feed falla (graceful degradation)
2. **Impacto:** Mínimo — <1% CPU, <10MB RAM
3. **Compatibilidad:** POSIX/ash compatible (OpenWrt 25.12.2)
4. **Independencia:** No interfiere con servicios existentes (AdGuardHome, dnsmasq, Tailscale)
5. **Notificaciones:** Todas a Telegram automáticamente
6. **Logs:** Almacenados en `/var/log/threat-alert/` para auditoría

---

**Fecha de instalación:** 2026-04-14 @ 21:04 UTC
**Router:** Flint-2 (GL-MT6000) @ 192.168.10.1
**OpenWrt:** 25.12.2 (r32802-f505120278)
