---
name: OpenWrt Firmware Update Checker
description: Script automático de monitoreo de nuevas versiones de OpenWrt con alertas a Telegram
type: project
originSessionId: 3ab63c79-a102-4073-9eb2-7c72eb994852
---
## OpenWrt Firmware Update Checker

**Ubicación**: `/usr/bin/monitor/openwrt_update_checker.sh`

**Instalación**: 2026-04-17 13:04 UTC

**Crontab**: `17 8 * * * /usr/bin/monitor/openwrt_update_checker.sh`
- Ejecuta diariamente a las **08:17 AM UTC** (evita contención de minuto 0)
- Hora local México City: **02:17 AM CST**

## Funcionalidad

El script:
1. **Consulta** las descargas oficiales de OpenWrt (`https://downloads.openwrt.org/releases/`)
2. **Compara** la versión local con la última disponible
3. **Detecta** nuevas versiones de forma automática
4. **Alerta** a Telegram solo si hay actualización nueva
5. **Evita spam** guardando estado (no repite alertas)

## Versión Actual en Flint-2

```
DISTRIB_RELEASE: 25.12.2
DISTRIB_REVISION: r32802-f505120278 (SNAPSHOT)
TARGET: mediatek/mt7986a (GL-MT6000)
```

## Ejecución Manual

```bash
# Ejecutar verificación manual
ssh root@192.168.10.1 /usr/bin/monitor/openwrt_update_checker.sh

# Ver logs
ssh root@192.168.10.1 tail -20 /var/log/openwrt_check.log

# Ver estado guardado (última versión notificada)
ssh root@192.168.10.1 cat /tmp/openwrt_version_latest.txt
```

## Alertas a Telegram

Cuando detecta una nueva versión, el script envía mensaje como:

```
🔄 OpenWrt Update Available

Device: Flint-2 (GL-MT6000)
Current Version: 25.12.2
Latest Available: 25.12.3

Download Link:
https://downloads.openwrt.org/releases/25.12.3/targets/mediatek/mt7986a/

To Update (SSH to router):
sysupgrade -v /tmp/openwrt.bin
```

## Configuración Necesaria

El script usa Telegram desde `/etc/monitor/config.sh`:
- `TG_BOT_TOKEN`: Token del bot (debe estar configurado)
- `TG_CHAT_ID`: ID del chat (debe estar configurado)

Si Telegram no está configurado, el script sigue funcionando pero no envía alertas (solo registra en logs).

## Archivos de Estado

| Archivo | Propósito | Ubicación |
|---------|-----------|-----------|
| `openwrt_version_latest.txt` | Última versión notificada | `/tmp/` |
| `openwrt_check.log` | Logs de ejecuciones | `/var/log/` |

## Cómo Funciona

1. **Detección de dispositivo**: Automática (Flint-2 → mediatek/mt7986a, Beryl → mediatek/mt7981)
2. **Obtención de versión actual**: Desde `/etc/os-release` (VERSION field)
3. **Consulta de versiones**: Scrapea el directorio de descargas
4. **Ordenamiento semántico**: Usa `sort -rV` (versioning sort descend)
5. **Comparación**: 
   - Si `LATEST != CURRENT` Y `LATEST != PREV_LATEST` → ALERTA
   - Si `LATEST == CURRENT` → Sin actualización disponible
   - Si `LATEST == PREV_LATEST` → Ya notificado antes

## Historial de Cambios

| Fecha | Cambio |
|-------|--------|
| 2026-04-17 13:04 | Script creado e instalado |
| 2026-04-17 13:04 | Crontab agregado (08:17 UTC) |
| 2026-04-17 13:04 | Prueba manual: OK (25.12.2 es actual) |

## Notas Técnicas

- **Sort versioning**: Usa `sort -rV` en lugar de `-t. -k1,1nr` para compatibilidad
- **Formato /etc/os-release**: OpenWrt 25.12 usa `VERSION="25.12.2"` (no DISTRIB_RELEASE)
- **Timeout**: 15 segundos en wget para evitar bloqueos
- **Compatibilidad**: BusyBox sh (ash) en OpenWrt 25.12.2
- **Logs**: Ubicados en `/var/log/openwrt_check.log` para auditoría

## Próximas Versiones

Cuando OpenWrt 26.x esté disponible:
```
[2026-XX-XX XX:XX:XX] ALERTA: Nueva actualización disponible: 26.0.0 (actual: 25.12.2)
```

El script detectará automáticamente y alertará vía Telegram (si está configurado).
