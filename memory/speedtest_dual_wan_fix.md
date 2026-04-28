---
name: Speedtest Dual-WAN — Fix ejecutado 2026-04-19
description: Corregido script speedtest-dual-wan.sh para que mida ambas WANs (Telmex + Megacable) y envíe Telegram correctamente
type: project
originSessionId: continued-b6dfda45-a2d0-479a-ac75-92b80d73bbbe
---

## Problema Detectado

**Antes del fix:**
- ✅ Megacable (secondwan) medía correctamente
- ❌ Telmex (WAN) no aparecía en métricas Prometheus
- ❌ Telegram se enviaba pero sin resultados de Telmex
- 🔍 Logs mostraban: `Completado WAN= SW=192.168.100.26` (WAN vacío)

---

## Root Cause

Script usaba:
```sh
IP_WAN=$(ip addr show wan 2>/dev/null | awk '/inet /{...}')
```

Pero **"wan" no es una interfaz física**. La interfaz real es **`eth1`** (192.168.1.74).

**Interfaces actuales:**
- **WAN (Telmex)**: `eth1` → 192.168.1.74 ← CORRECTA
- **secondwan (Megacable)**: `lan1` → 192.168.100.26 ← YA FUNCIONABA

---

## Fixes Aplicados

### Fix #1: Corregir obtención de IP_WAN

**Cambio en `/etc/script/speedtest-dual-wan.sh` línea ~90:**

```sh
# ANTES (incorrecto)
IP_WAN=$(ip addr show wan 2>/dev/null | awk '/inet /{split($2,a,"/");print a[1]}')

# DESPUÉS (correcto)
IP_WAN=$(ip addr show eth1 2>/dev/null | awk '/inet /{split($2,a,"/");print a[1]}')
```

**Backup guardado:** `/etc/script/speedtest-dual-wan.sh.bak`

---

### Fix #2: Agregar logging Telegram

**Cambios para visibilidad:**

```sh
# Antes: función tg_send() enviaba a /dev/null sin logs
tg_send() {
    curl -s -X POST "..." -o /dev/null 2>&1
}

# Después: agrega logger y captura HTTP status
tg_send() {
    logger -t speedtest "Enviando Telegram..."
    curl -s -X POST "..." -w "HTTP:%{http_code}" 2>&1 | logger -t speedtest
}
```

**Beneficio**: Logs muestran si Telegram se envió y con qué status HTTP.

---

## Validación Post-Fix

**Prueba ejecutada:** 2026-04-19 21:40 UTC

### Estado Prometheus

⚠️ **Prometheus NO está activo** (removido a partir de 2026-04-19)

Aunque el script genera `/tmp/prom-metrics/speedtest.prom`, **no hay servidor Prometheus escuchando**.

Última ejecución generó (antes de desactivar):
```
openwrt_speedtest_download_mbps{wan="telmex"} 352.29
openwrt_speedtest_download_mbps{wan="megacable"} 207.47
openwrt_speedtest_upload_mbps{wan="telmex"} 359.81
openwrt_speedtest_upload_mbps{wan="megacable"} 209.84
openwrt_speedtest_latency_ms{wan="telmex"} 2.65
openwrt_speedtest_latency_ms{wan="megacable"} 2.97
openwrt_speedtest_jitter_ms{wan="telmex"} 0.08
openwrt_speedtest_jitter_ms{wan="megacable"} 0.03
openwrt_speedtest_loss_pct{wan="telmex"} 0.0
openwrt_speedtest_loss_pct{wan="megacable"} 0.0
```

### Logs ✅

```
Sun Apr 19 21:40:21 2026 user.notice speedtest: Enviando Telegram...
Sun Apr 19 21:40:22 2026 user.notice speedtest: {"ok":true,"result":...}
Sun Apr 19 21:40:22 2026 user.notice speedtest: HTTP:200
Sun Apr 19 21:40:22 2026 user.notice speedtest: Completado WAN=192.168.1.74 SW=192.168.100.26
```

### Telegram ✅

Mensaje recibido con ambas WANs:

```
🌐 Speedtest — Flint-2
📅 2026-04-19 21:39

TELMEX WAN (192.168.1.74)
⬇️ 352.29 Mbps  ⬆️ 359.81 Mbps
📶 Latencia: 2.65 ms  Loss: 0.0%
🔗 https://www.speedtest.net/result/c/0457848a-677e-4fd8-9d94-0a026433c15c

Megacable (192.168.100.26)
⬇️ 207.47 Mbps  ⬆️ 209.84 Mbps
📶 Latencia: 2.97 ms  Loss: 0.0%
🔗 https://www.speedtest.net/result/c/f34d4cb4-971f-4a79-bfd3-e4ded59c9ef6
```

---

## Resumen de WANs

| Parámetro | Telmex (WAN) | Megacable (secondwan) |
|-----------|-------|-----------|
| **Interfaz física** | eth1 | lan1 |
| **IP** | 192.168.1.74 | 192.168.100.26 |
| **Gateway** | 192.168.1.254 | 192.168.100.1 |
| **DHCP** | Sí | Sí |
| **Velocidad actual** | 352 Mbps DL / 359 Mbps UL | 207 Mbps DL / 209 Mbps UL |
| **Latencia** | 2.65 ms | 2.97 ms |
| **Jitter** | 0.08 ms | 0.03 ms |
| **Packet Loss** | 0% | 0% |

---

## Próximas Ejecuciones Automáticas

**Crontab:** Semanal (visto en master_weekly.sh)

```
📅 Próximo: Domingo 08:00 UTC
   → Ejecuta: /bin/sh /etc/script/speedtest-dual-wan.sh
   → Mide ambas WANs
   → Envía Telegram con resultados
   → Genera /tmp/prom-metrics/speedtest.prom (no usado, Prometheus desactivo)
```

**⚠️ Nota:** El archivo Prometheus se genera pero no es procesado (sin servidor Prometheus activo).

---

## Archivos Modificados

| Archivo | Cambio | Fecha |
|---------|--------|-------|
| `/etc/script/speedtest-dual-wan.sh` | IP_WAN: wan → eth1, agregar logging Telegram | 2026-04-19 21:38 |
| `/etc/script/speedtest-dual-wan.sh.bak` | Backup pre-fix | 2026-04-19 21:38 |

---

## Notas Técnicas

### Interfaz "wan" vs "eth1"

En OpenWrt UCI, "wan" es un nombre lógico definido en `/etc/config/network`:
```
network.wan.device='eth1'
```

El script no debería usar nombres lógicos de OpenWrt (`ip addr show wan`), sino interfaces físicas (`eth1`).

### Speedtest binary

El speedtest CLI está en `/etc/script/speedtest` (binario compiled Ookla).

Usa flags:
- `-i <IP>` — fuerza interfaz específica (necesario con MWAN3 dual-WAN)
- `-f json` — salida JSON (anterior fix, ahora usa human-readable)
- `--accept-license --accept-gdpr` — aceptar términos

### IP Rules MWAN3

Las rules que usa el script:
```
ip rule add from <IP> table <table> priority 100
```

Tabla 1 = WAN (Telmex), Tabla 2 = secondwan (Megacable)

---

## Estado Final

✅ **Speedtest dual-WAN completamente funcional**
- Ambas WANs miden correctamente ✅ (Telmex 352Mbps, Megacable 207Mbps)
- Telegram recibe resultados de ambas ✅
- Métricas Prometheus generadas pero **no activas** (servidor removido)
- Logs muestran ejecución y status HTTP ✅
- Próxima ejecución: Domingo 08:00 UTC (reporte en Telegram)
