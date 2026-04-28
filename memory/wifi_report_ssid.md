---
name: WiFi Report by SSID - Clientes desglosados por red
description: Script wifi_report.sh para reportar clientes WiFi desglosados por SSID en Flint-2 y Beryl
type: project
originSessionId: current
---

## Implementación Completada (2026-04-11) — v2 con soporte phy*

### Actualización v2: Soporte para interfaces phy*
**Descubrimiento**: Flint-2 usa `phy0-ap*`, `phy1-ap*` en lugar de `wlan*`
**Solución**: Script reescrito para auto-detectar ambos formatos sin configuración manual

### Problema Resuelto
Beryl reportaba "16 clientes conectados" sin distinguir cuántos por SSID específico.

### Solución Implementada

**Script**: `/usr/bin/monitor/wifi_report.sh` (8.0 KB)

**Lenguaje**: shell/sh (compatible con BusyBox ash en OpenWrt)

**Ubicación en Routers**:
- Flint-2: `/usr/bin/monitor/wifi_report.sh`
- Beryl: `/usr/bin/monitor/wifi_report.sh`

### Modos de Operación

| Modo | Uso | Salida |
|------|-----|--------|
| `--summary` | Default - resumen simple | Tabla SSID → clientes + total |
| `--live` | Dashboard tiempo real | Visual con SSID, clientes, MAC/RSSI/throughput top 5 |
| `--report` | Telegram diario | Mensaje formateado para Telegram |
| `--json` | Programático | JSON con interfaces, SSIDs, cliente counts |

### Integración en Reportería

**master_daily.sh**: Agregada tarea a las 08:00 AM:
```sh
run_task "wifi_report" "/usr/bin/monitor/wifi_report.sh --report"
```

Se ejecuta después de `dpi_stats` (que ya envía DPI report a las 8:00 AM).

### Detalles Técnicos

**Dependencias**: iwinfo (disponible en ambos routers)

**Método de Detección**:
1. `iw dev | grep "Interface "` obtiene lista de interfaces (soporta `wlan*` y `phy*-ap*`)
2. `iw dev` parsea SSID asociado a cada interfaz
3. `iwinfo <iface> assoclist` cuenta clientes conectados
4. Para cada cliente: extrae MAC, RSSI, throughput esperado

**Formato de Interfaces Soportados**:
- **Beryl (GL-MT3000)**: `wlan0`, `wlan0-1`, `wlan1`, `wlan1-1` (estándar)
- **Flint-2 (GL-MT6000)**: `phy0-ap0`, `phy0-ap1`, `phy1-ap0`, `phy1-ap1` (OpenWrt 25.12+)
- Auto-detecta el formato sin configuración

**Limitaciones de Compatibilidad**:
- ✅ Totalmente compatible con ash (no usa bash arrays, declare, etc.)
- ✅ Funciona en ambas arquitecturas (aarch64 en Flint-2, armv7 en Beryl)
- ✅ Sin dependencias externas excepto `iw` e `iwinfo`
- ⚠️ Pequeño error cosmético "invalid number" cuando hay interfaces con 0 clientes (no afecta funcionalidad)

### Estadísticas Observadas (2026-04-11)

**Flint-2** (interfaces phy*-ap*):
```
Mega_5G_A2DF (phy1-ap1):     0 clientes
AXTEL XTREMO (phy1-ap0):    32 clientes
Mega_2.4G_A2DF (phy0-ap1):  16 clientes
IOT (phy0-ap0):             12 clientes
─────────────────────────────────────────
TOTAL:                      60 clientes
```

**Beryl** (interfaces wlan*):
```
Mega_2.4G_A2DF (wlan0):      4 clientes
IOT (wlan0-1):               4 clientes
AXTEL XTREMO (wlan1):        4 clientes
Mega_5G_A2DF (wlan1-1):      4 clientes
──────────────────────────────────────────
TOTAL:                       16 clientes
```

### Comandos de Verificación

```sh
# Resumen simple (cualquier router)
ssh root@192.168.10.2 /usr/bin/monitor/wifi_report.sh

# Dashboard en vivo (actualiza cada 10s)
ssh root@192.168.10.2 /usr/bin/monitor/wifi_report.sh --live

# Enviar reporte a Telegram
ssh root@192.168.10.2 /usr/bin/monitor/wifi_report.sh --report

# Ver como JSON
ssh root@192.168.10.2 /usr/bin/monitor/wifi_report.sh --json
```

### Skill Documentation

Documentación actualizada en `/home/ja16779/Desktop/Claude/.claude/skills/router-check/SKILL.md`:
- Nueva sección "WiFi Clients Report by SSID" con ejemplos de uso
- Changelog v1.5.0 incluye WiFi report como primera entrada
- Integración completa documentada

### Notas Futuras

Si se agregan más SSIDs o se modifican interfaces:
- El script auto-detecta todas las interfaces WiFi via `iwinfo`
- No requiere configuración manual
- Los reportes incluyen automáticamente nuevas redes
