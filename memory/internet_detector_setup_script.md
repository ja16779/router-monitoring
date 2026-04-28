---
name: Script de Instalación y Actualización internet-detector
description: Script para instalar, actualizar y configurar internet-detector desde GitHub automáticamente
type: reference
originSessionId: 5df9b90a-0dee-4075-a28c-7433d3d62640
---
## internet_detector_setup.sh

**Ubicación:** `/usr/bin/monitor/internet_detector_setup.sh`

**Funcionalidad:** Automatiza instalación, configuración, y actualización de internet-detector desde GitHub (gSpotx2f/packages-openwrt).

### Modos de operación

```sh
internet_detector_setup.sh [--install|--update|--check|--config]
```

| Modo | Función |
|------|---------|
| `--install` (default) | Instala si no está presente. Si ya está, verifica que el servicio esté corriendo |
| `--update`, `-u` | Revisa nuevas versiones en GitHub y actualiza si la hay. Notifica por Telegram |
| `--check`, `-c` | Solo muestra versión instalada vs disponible sin hacer nada |
| `--config` | Re-aplica configuración UCI sin reinstalar (útil para resets o cambios manuales) |

### Configuración automática aplicada

**Instancia: internet** (Telmex WAN — eth1)
- Ping a `45.90.28.0` y `45.90.30.0` (NextDNS bootstrap)
- Detección de IP pública: `amazonaws` (HTTP via checkip.amazonaws.com) — DNS bloqueado por Telmex en eth1
- **Telegram: forzado por lan1** — Telmex bloquea api.telegram.org en eth1
- Notificaciones en desconexión y reconexión

**Instancia: secondwan** (Megacable WAN — lan1)
- Mismas pruebas y configuración
- IP pública: `ipecho` (alternative provider)
- Telegram sin restricciones via lan1

Ambas instancias usan:
- Chequeo cada 30s (online) / 5s (offline)
- 2 intentos de conexión, timeout 2s
- Tamaño ICMP: 56 bytes
- Módulos desactivados: LED, reboot, network restart, modem restart, email, scripts

### Verificación

```sh
# Ver estado
/usr/bin/monitor/internet_detector_setup.sh --check

# Salida esperada (al día):
# Instalada : 1.7.3-r1
# Disponible: 1.7.3-r1
# Al día
```

### Integración recomendada

**En crontab** (revisar updates semanalmente):
```sh
0 4 * * 0 /usr/bin/monitor/internet_detector_setup.sh --update
```

**En master_weekly.sh** (chequeo semanal automático):
```sh
run_task "internet_detector" "/usr/bin/monitor/internet_detector_setup.sh --check"
```

### Notas técnicas

- Usa API de GitHub: `https://api.github.com/repos/gSpotx2f/packages-openwrt/contents/25.12`
- Parsing JSON sin dependencias externas (solo shell + grep)
- Descarga de `.apk` desde raw.githubusercontent.com
- Credenciales Telegram leídas de `/etc/monitor/config.sh`
- Notificaciones via Telegram si hay actualización o error
- Versión actual: **1.7.3-r1** (2026-04-14)

### Troubleshooting

**"Disponible: no se pudo obtener"**
- GitHub API no respondió. Chequear conectividad: `curl -s https://api.github.com/repos/gSpotx2f/packages-openwrt/contents/25.12 | wc -c` (debería ser > 10000 bytes)

**Telegram no notifica**
- Verificar credenciales en `/etc/monitor/config.sh`
- Probar manualmente: `curl -X POST https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage ...`

**Script dice "ya instalado" pero no funciona**
- Reiniciar manualmente: `/usr/bin/monitor/internet_detector_setup.sh --config`
- O reinstalar completo: `apk del internet-detector* luci-app-internet-detector* && /usr/bin/monitor/internet_detector_setup.sh --install`
