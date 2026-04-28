# Memory Index

This file indexes all memory files stored in this directory.

Last updated: 2026-04-27 v44 - Unbound Dashboard FINAL (Auto-instalación + Persistencia)

---

## Project Memories

| File | Name | Description |
|------|------|-------------|
| [network_topology.md](network_topology.md) | Red doméstica - topología actual | Topología completa de la red doméstica con routers, repetidores y VLANs |
| [scripts_monitor.md](scripts_monitor.md) | Scripts de monitoreo en Flint-2 | Scripts personalizados instalados en el Flint-2 |
| [super_monitor_consolidation.md](super_monitor_consolidation.md) | Consolidación 4 Maestros Especializados | 38 scripts consolidados en 4 maestros (master_realtime, master_hourly, master_daily, master_weekly) |
| [adguardhome_lg_bypass.md](adguardhome_lg_bypass.md) | AdGuardHome - Cliente LG Bypass | Cliente Tv Lg (192.168.10.103) con filtros deshabilitados para LG TV Apps |
| [usteer_cli_wrapper.md](usteer_cli_wrapper.md) | Usteer CLI Wrapper — ubus Implementation | CLI wrapper para usteer via ubus (RPC), binario oficial no compilado para aarch64. Monitorea 21 clientes conectados, ~76 totales |
| [unbound_dashboard_completed_20260427.md](unbound_dashboard_completed_20260427.md) | Unbound DNS Dashboard — Final | Dashboard HTML Top 10 dominios/clientes, auto-refresh 30s, cron cada min, auto-instalación sysupgrade via uci-defaults |
| [dpi_netifyd_ndpi.md](dpi_netifyd_ndpi.md) | [NOT AVAILABLE] DPI - netifyd + nDPI | netifyd no disponible en OpenWrt 25.12.2 APK. Verificado 2026-04-17: sin binarios compilados para esta arquitectura |
| [wifi_report_ssid.md](wifi_report_ssid.md) | WiFi Report by SSID | Script wifi_report.sh reporta clientes desglosados por SSID en Flint-2 y Beryl |
| [threat_alert_system_mvp.md](threat_alert_system_mvp.md) | Threat Alert System — MVP Completado | Sistema OpenWrt de detección de amenazas con 387 IPs C2 bloqueadas, anomaly detection, alertas Telegram |
| [openwrt_firmware_updater.md](openwrt_firmware_updater.md) | OpenWrt Firmware Update Checker | Script automático `/usr/bin/monitor/openwrt_update_checker.sh` — monitorea nuevas versiones, alerta a Telegram (cron 08:17 UTC) |
| [rsync_sysupgrade_sync.md](rsync_sysupgrade_sync.md) | Rsync Smart Sync v2 — Sincronización Inteligente | Script `/usr/bin/monitor/rsync_sysupgrade_sync.sh` — detección MD5 de cambios, solo sincroniza si hay modificaciones (cron cada 6h, --force para forzar) |
| [dns_configuration_final.md](dns_configuration_final.md) | DNS Final — Completada y Verificada | AGH:53 → Unbound:5335 (recursivo con ICANN AXFR). auth-zones activas. validator_ntp=0 fix |
| [dns_architecture.md](dns_architecture.md) | [DEPRECATED] Arquitectura DNS antigua | Obsoleta: AGH (53) → Unbound (5335) → upstreams estáticos |
| [dns_architecture_dot.md](dns_architecture_dot.md) | [DEPRECATED] DNS NextDNS DoH | Obsoleta (2026-04-13): dnsmasq:53 → AGH:3053 → NextDNS DoH |
| [dns_architecture_actual.md](dns_architecture_actual.md) | [OBSOLETE] DNS Arquitectura Verificada | Antigua (2026-04-17 08:00): Unbound forwarder sin auth-zones |
| [dns_architecture_updated.md](dns_architecture_updated.md) | [OBSOLETE] DNS Óptima Parcial | Intermedia (2026-04-17 08:26): auth-zones no se generaban (faltaba validator_ntp=0) |
| [internet_detector_setup_script.md](internet_detector_setup_script.md) | Script instalación internet-detector | `/usr/bin/monitor/internet_detector_setup.sh` — instala, configura y actualiza desde GitHub |
| [ruantiblock_installed.md](ruantiblock_installed.md) | Ruantiblock Anti-DPI Instalado | Daemon para evadir DPI (evasión de bloqueos de Telmex/Megacable), instalado 2026-04-14 |
| [telmex_telegram_block_recent.md](telmex_telegram_block_recent.md) | Bloqueo Reciente Telegram en Telmex | Telmex bloqueó api.telegram.org entre 2026-04-07 y 2026-04-14 (DPI escalation) |
| [dns_cache_warmup.md](dns_cache_warmup.md) | DNS Optimization — Cache persistence + warm-up + compresión | 3 optimizaciones 2026-04-19: cache restore USB, warm-up 500 dom, querylog gzip. Hit rate post-reinicio: 60% inmediato |
| [flint2_optimized_state.md](flint2_optimized_state.md) | Flint-2 estado optimizado 2026-04-19 | Estado final de Flint-2 después de todas las optimizaciones. Production-ready, DNS ~60% hit rate, dual-WAN OK, 4 SSIDs, Tailscale exit node activo |
| [beryl_wifi_optimization.md](beryl_wifi_optimization.md) | Beryl WiFi Optimization — 4 cambios | Canal 5GHz 56→149 (sin DFS, +2dBm), legacy_rates=0, max_inactivity=600s, txpower 20/26dBm. Aplicado 2026-04-19 |
| [wifi_analyzer_monitoring.md](wifi_analyzer_monitoring.md) | WiFi Analyzer — Monitoreo automático (Opción A) | script activado en crontab cada 12h (03:00, 15:00 UTC). Análisis + alertas Telegram, sin cambios automáticos (manual review). 2026-04-19 |
| [speedtest_dual_wan_fix.md](speedtest_dual_wan_fix.md) | Speedtest Dual-WAN Fix (2026-04-19) | Corregido eth1 para Telmex (antes "wan" vacío), agregado logging Telegram. Mide ambas WANs + notificaciones. Prometheus desactivado. |
| [wifi_roaming_detector.md](wifi_roaming_detector.md) | WiFi Roaming Detector — Sin usteer (2026-04-19) | Script cada 30s detecta cuando clientes hacen roaming entre Flint-2 y Beryl. Alertas Telegram + logs. 14 clientes monitoreados actualmente. |
| [iot_dhcp_flapping_fix.md](iot_dhcp_flapping_fix.md) | IoT DHCP Flapping Fix — Resolución (2026-04-22) | Se resolvió flapping habilitando DHCP en VLAN IoT (br-lan.8). Dispositivos IoT: reconexiones de cada 42s → cada 2-3 min |
| [rps_rfs_optimization.md](rps_rfs_optimization.md) | RPS/RFS Network Optimization (2026-04-22) | Distribución multi-core: eth0/eth1 de 1 core → 4 cores. RFS habilitado (32768). Persistente en rc.local |
| [rps_rfs_monitoring.md](rps_rfs_monitoring.md) | RPS/RFS Monitoring & Validation (2026-04-22) | Scripts, procedimientos y troubleshooting para monitorear RPS/RFS |
| [rps_rfs_implementation_complete.md](rps_rfs_implementation_complete.md) | RPS/RFS Complete Implementation (2026-04-22) | Opción A (router-check) + Opción B (monitor script) + Opción C (documentation) |
| [beryl_offline_incident_20260422.md](beryl_offline_incident_20260422.md) | Beryl Offline Incident — 2026-04-22 | Beryl se colgó (no respondía SSH), reinicio de ambos routers resolvió el problema |
| [re220_offline_incident_20260422.md](re220_offline_incident_20260422.md) | RE220 Offline Incident — Resolución Final (2026-04-23) | RE220 actualmente desconectado; DHCP estático + script configurados. Notificación Telegram lista cuando se reconecte. |
| [usteer_removal_20260424.md](usteer_removal_20260424.md) | Usteer Desinstalación Completa (2026-04-24) | Usteer desintalado; reemplazado con SSID 2.4GHz adicional para mejor cobertura. 5 SSIDs en ambos routers. Daemon matado (PID 18696) |
| [iot_ssid_fix_20260424.md](iot_ssid_fix_20260424.md) | IoT SSID Fix — SSIDs en red correcta (2026-04-24) | Mega_2.4G_A2DF y Mega_5G_A2DF movidas de LAN a IOT VLAN, resolviendo flapping de dispositivos IoT |
| [nextdns_critical_domains_sync_20260424.md](nextdns_critical_domains_sync_20260424.md) | NextDNS Critical Domains Sync (2026-04-24 13:37 UTC) | Agregados 3 dominios críticos (a.root-servers.net, m2.tuyacn.com, api.amazonalexa.com) al whitelist de NextDNS |
| [dns_wan_fallback_config_20260424.md](dns_wan_fallback_config_20260424.md) | [SUPERSEDED] DNS WAN Fallback Configuration | Reemplazado por NextDNS Ultralow DoH optimization |
| [nextdns_ultralow_optimization_20260424.md](nextdns_ultralow_optimization_20260424.md) | NextDNS Ultralow DoH Optimization (2026-04-24) | Cambio Anycast (66ms) → Ultralow DoH (13ms). -80% latencia, protocolo DoH, IP ultralow 200.25.32.197 |
| [dns_latency_optimization_complete_20260424.md](dns_latency_optimization_complete_20260424.md) | DNS Latency Optimization — Solución Completa (2026-04-24) | Removimiento DNSSEC validator (0.24ms), num-threads=4, ujail fix, AdGuardHome bug. 170ms → 0.24ms (-99.8%) ✅ |
| [adguardhome_upstream_response_time_bug_20260424.md](adguardhome_upstream_response_time_bug_20260424.md) | AdGuardHome Upstream Response Time Bug | Bug #6818 - Dashboard muestra 10x latencia falsa. Usar unbound-control stats para valor real. |
| [master_scripts_timeout_protection_20260427.md](master_scripts_timeout_protection_20260427.md) | Master Scripts - Timeout Protection | Todos los 4 master scripts con timeout: realtime=300s, hourly=600s, daily=1800s, weekly=2700s. master_5min.sh eliminado |
| [mwan3_configuration_20260427.md](mwan3_configuration_20260427.md) | MWAN3 Dual-WAN Configuration | Configuración Telmex (wan) + Megacable (secondwan): interfaces, health checks, policies, rules, failover automático |
| [mwan3_optimization_fase12_20260427.md](mwan3_optimization_fase12_20260427.md) | MWAN3 Optimization — FASE 1 + FASE 2 | Reliability agresivo (1/3), interval 10s (-50% CPU), tracking IPs diversificadas, alerts Telegram, sticky timeouts ágiles |
| [mwan3_healthcheck_fix_20260427.md](mwan3_healthcheck_fix_20260427.md) | MWAN3 Healthcheck Fix — Ajuste de Reliability | Reliability corregido 1/3 → 2/3/2/2, quality checks normalizados (250ms, 15%), script alertas reparado |

## User Memories

| File | Name | Description |
|------|------|-------------|
| [ssh_access.md](ssh_access.md) | Acceso SSH a routers | Credenciales y métodos de acceso SSH a los routers |

## Feedback Memories

| File | Name | Description |
|------|------|-------------|
| [feedback_notificar.md](feedback_notificar.md) | notificar.sh no soporta mensajes multilinea | notificar.sh usa -d en curl (no --data-urlencode), rompe mensajes con saltos de línea |
| [feedback_ash_shell.md](feedback_ash_shell.md) | Limitaciones de ash/BusyBox en OpenWrt | Restricciones conocidas del shell ash en OpenWrt 25.12 |
