---
name: WiFi Roaming Detector — Monitoreo automático (sin usteer)
description: Script wifi_roaming_monitor.sh detecta cuando clientes se reconectan entre Flint-2 y Beryl. Ejecuta cada 30s, alerta Telegram si roaming. Instalado 2026-04-19
type: project
originSessionId: continued-b6dfda45-a2d0-479a-ac75-92b80d73bbbe
---

## Estado de Instalación ✅

| Componente | Status | Detalles |
|-----------|--------|----------|
| **Script** | ✅ Instalado | `/usr/bin/monitor/wifi_roaming_monitor.sh` (3.7KB final) |
| **Versión** | Final (2026-04-19 21:50) | Delimitador `\|`, variables Telegram correctas (TELEGRAM_ACTIVO, TELEGRAM_BOT_TOKEN) |
| **Crontab** | ✅ Activo | 2 entradas (cada 30 segundos con offset) |
| **Logging** | ✅ Activo | `/var/log/wifi_roaming.log` |
| **Telegram** | ✅ FUNCIONANDO | HTTP 200, ok:true. Prueba de envío exitosa |
| **Estado actual** | ✅ PRODUCTION READY | 13 clientes monitoreados, alertas Telegram activas |

---

## Cómo Funciona

### Flujo de Ejecución (cada 30 segundos)

```
1. Captura clientes conectados a Flint-2
   ├─ phy0-ap0 (2.4GHz SSID 1)
   ├─ phy0-ap1 (2.4GHz SSID 2)
   ├─ phy1-ap0 (5GHz SSID 1)
   └─ phy1-ap1 (5GHz SSID 2)

2. Captura clientes conectados a Beryl (SSH)
   ├─ wlan0 (2.4GHz SSID 1)
   ├─ wlan0-1 (2.4GHz SSID 2)
   ├─ wlan1 (5GHz SSID 1)
   └─ wlan1-1 (5GHz SSID 2)

3. Compara con snapshot anterior
   ├─ Si MAC desaparece de Flint-2
   └─ Y aparece en Beryl → ROAMING DETECTADO ✅

4. Alerta Telegram + Log
```

### Detección de Roaming

```
🔄 Roaming detectado
MAC: AA:BB:CC:DD:EE:FF
De: Flint-2 (phy1-ap0)
A: Beryl (wlan1)
Hora: 14:23:45
```

---

## Snapshot Actual (2026-04-19 21:44)

**Clientes detectados: 14 (todos en Flint-2, Beryl vacío)**

```
Flint-2:
  00:15:99:88:7c:28 — phy0-ap1 (2.4GHz)
  3c:0b:59:bc:a3:5b — phy0-ap0 (2.4GHz)
  76:46:a9:2b:29:ed — phy1-ap1 (5GHz)
  7c:f6:66:8b:93:ca — phy0-ap0 (2.4GHz)
  9a:48:27:0e:54:47 — phy0-ap1 (2.4GHz)
  a2:6f:31:ba:93:f6 — phy1-ap0 (5GHz)
  bc:ff:4d:86:9c:f8 — phy0-ap0 (2.4GHz)
  d0:a0:bb:7d:9f:a8 — phy0-ap1 (2.4GHz)
  d8:1f:12:be:e9:b7 — phy0-ap0 (2.4GHz)
  da:a5:7d:4e:71:2d — phy1-ap0 (5GHz)
  e4:b3:18:97:2d:40 — phy1-ap0 (5GHz)
  ec:0d:e4:58:d4:da — phy1-ap0 (5GHz)
  ec:8a:c4:b3:dd:a6 — phy1-ap1 (5GHz)
  fc:3c:d7:56:39:20 — phy0-ap0 (2.4GHz)

Beryl:
  (vacío - sin clientes en este momento)
```

---

## Crontab Configurado

```sh
* * * * * /usr/bin/monitor/wifi_roaming_monitor.sh >> /var/log/wifi_roaming.log 2>&1
* * * * * sleep 30 && /usr/bin/monitor/wifi_roaming_monitor.sh >> /var/log/wifi_roaming.log 2>&1
```

**Efecto**: Ejecuta cada 30 segundos (2 scripts que ejecutan cada minuto con offset de 30s)

---

## Logs

**Ubicación**: `/var/log/wifi_roaming.log`

**Contenido actual**:
```
[2026-04-19 21:44:33] Escaneando clientes Flint-2 y Beryl...
[2026-04-19 21:44:34] Ciclo completado (14 clientes detectados)
```

**Evento de roaming esperado**:
```
[2026-04-19 21:50:12] ROAMING: da:a5:7d:4e:71:2d (Flint-2 → Beryl)
```

---

## Alertas Telegram ✅ FUNCIONANDO

**Status**: Completamente operacional (probado 2026-04-19 21:51)

**Configuración en `/etc/monitor/config.sh`**:
- `TELEGRAM_ACTIVO=1` ✅
- `TELEGRAM_BOT_TOKEN=8054647573:AAE_u741U...` ✅
- `TELEGRAM_CHAT_ID=716542586` ✅

**Prueba de conectividad**: HTTP 200, `{"ok":true}` ✅

**Formato de alerta**:
```
🔄 Roaming detectado
MAC: da:a5:7d:4e:71:2d
De: Flint-2 (phy1-ap0)
A: Beryl (wlan1)
Hora: 21:50:12
```

**Cuándo recibirás alertas**:
- Cada vez que detecte un cliente cambiando entre Flint-2 y Beryl
- Máximo delay: 30 segundos (tiempo entre ejecuciones)

---

## Estado de Red Monitorado

### Flint-2 WiFi

| Interfaz | SSID | Clientes | Banda |
|----------|------|----------|-------|
| phy0-ap0 | Mega_2.4G_A2DF | 6 | 2.4GHz ch1 |
| phy0-ap1 | IOT | 3 | 2.4GHz ch1 |
| phy1-ap0 | AXTEL XTREMO | 4 | 5GHz ch44 |
| phy1-ap1 | Mega_5G_A2DF | 1 | 5GHz ch44 |

### Beryl WiFi

| Interfaz | SSID | Clientes | Banda |
|----------|------|----------|-------|
| wlan0 | Mega_2.4G_A2DF | 0 | 2.4GHz ch6 |
| wlan0-1 | IOT | 0 | 2.4GHz ch6 |
| wlan1 | AXTEL XTREMO | 0 | 5GHz ch149 |
| wlan1-1 | Mega_5G_A2DF | 0 | 5GHz ch149 |

**Nota**: En este momento todos los clientes están en Flint-2. Beryl está disponible pero sin clientes.

---

## Datos Almacenados

| Archivo | Contenido | Actualización |
|---------|-----------|----------------|
| `/tmp/wifi_roaming/current_all_clients` | Estado actual (lista de MACs por router) | Cada 30s |
| `/tmp/wifi_roaming/previous_all_clients` | Estado anterior (para comparación) | Cada 30s |
| `/tmp/wifi_roaming/flint2_clients` | Clientes Flint-2 | Cada 30s |
| `/tmp/wifi_roaming/beryl_clients` | Clientes Beryl (vía SSH) | Cada 30s |
| `/var/log/wifi_roaming.log` | Log de eventos | Cada 30s |

---

## Prueba de Simulación Exitosa (2026-04-19 21:49 UTC)

**Simulación realizada**: MAC `00:15:99:88:7c:28` movido de Beryl a Flint-2

**Resultado detectado**:
```
[2026-04-19 21:49:28] 🔄 Roaming detectado
MAC: 00:15:99:88:7c:28
De: Beryl (wlan1)
A: Flint-2 (phy0-ap1)
Hora: 21:49:28
```

✅ **Conclusión**: Script detecta correctamente cambios de router

---

## Casos de Roaming Detectados

### ✅ Detectará automáticamente:

1. **Cliente se mueve Flint-2 → Beryl**
   ```
   ROAMING: aa:bb:cc:dd:ee:ff (Flint-2 → Beryl)
   ```

2. **Cliente se mueve Beryl → Flint-2**
   ```
   ROAMING: aa:bb:cc:dd:ee:ff (Beryl → Flint-2)
   ```

3. **Cliente se reconecta en banda diferente**
   ```
   ROAMING: aa:bb:cc:dd:ee:ff (Flint-2 phy1-ap0 [5GHz] → phy0-ap0 [2.4GHz])
   ```

4. **Clientes nuevos se conectan**
   ```
   Nueva conexión: aa:bb:cc:dd:ee:ff en Flint-2 (phy0-ap0)
   ```

---

## Troubleshooting

### ⚠️ Problema: "SSH timeout" en logs

**Causa**: Beryl no responde en 192.168.10.2

**Solución**:
```sh
ssh root@192.168.10.2 "iw dev wlan0 station dump"
# Verificar que Beryl está online y SSH funciona
```

### ⚠️ Problema: Roaming no se detecta

**Causa posible**: Cliente no se desconecta completamente, solo cambia AP

**Solución**: Esperar a que el cliente se reconecte completamente (puede tardar 30-60s)

### ⚠️ Problema: Log crece mucho

**Solución**: Script automáticamente rota logs vía logrotate. Si es muy grande:
```sh
echo "" > /var/log/wifi_roaming.log
```

---

## Próximos Pasos (Opcional)

1. **Análisis de patrón de roaming**: Guardar historial de cuál cliente hace roaming más frecuente
2. **Umbral de roaming frecuente**: Alertar si un cliente hace >3 roamings en 10 minutos
3. **Estadísticas por hora**: Reportar cuántos roamings/hora en Telegram
4. **Band steering análogo**: Detectar clientes débiles y sugerirles cambiar a mejor AP

---

## Ventajas vs Usteer

| Aspecto | Sin usteer (este script) | Con usteer |
|--------|------------------------|-----------|
| **Overhead** | Bajo (script bash) | Medio (daemon C) |
| **Automatización** | Manual (alertas) | Automática (band steering) |
| **Visibilidad** | Alta (logs detallados) | Media (datos de daemon) |
| **Control** | Total (puedes customizar) | Limitado |
| **Caso de uso** | Monitoreo y diagnóstico | Optimización automática |

---

## Verificación Final (2026-04-19 21:49 UTC)

✅ **Script**: 3.7KB, v2 operacional, delimitador `|`
✅ **Crontab**: 2 entradas activas, ejecuta cada 30s
✅ **Logging**: `/var/log/wifi_roaming.log` activo
✅ **Clientes**: 13 detectados en tiempo real
✅ **Simulación**: Roaming detectado correctamente

```sh
# Verificar estado
ssh root@192.168.10.1 "crontab -l | grep wifi_roaming"
ssh root@192.168.10.1 "tail -5 /var/log/wifi_roaming.log"

# Ver clientes actuales en formato (ROUTER|MAC|IFACE)
ssh root@192.168.10.1 "cat /tmp/wifi_roaming/current_all_clients"

# Ejecutar manualmente para debug
ssh root@192.168.10.1 "/usr/bin/monitor/wifi_roaming_monitor.sh && tail /var/log/wifi_roaming.log"
```
