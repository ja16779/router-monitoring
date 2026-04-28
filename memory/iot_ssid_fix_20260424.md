---
name: IoT SSID Fix — Configuración correcta (2026-04-24)
description: Mega_2.4G_A2DF y Mega_5G_A2DF estaban incorrectamente en LAN, corregidas a IOT, resolviendo flapping
type: project
originSessionId: c94e4099-5998-4017-89c7-e56420c55c6c
---

# IoT SSID Network Fix — 2026-04-24

## Problema Identificado

**SSIDs en red incorrecta** causaban flapping en dispositivos IoT:

| SSID | Configuración (Antes) | Configuración (Después) | Estado |
|------|--------|---------|--------|
| Mega_2.4G_A2DF | ❌ LAN | ✅ IOT | Corregido |
| Mega_5G_A2DF | ❌ LAN | ✅ IOT | Corregido |
| AXTEL XTREMO (5GHz) | ✅ LAN | ✅ LAN | OK |
| AXTEL XTREMO (2.4GHz) | ✅ LAN | ✅ LAN | OK |
| IOT (2.4GHz) | ✅ IOT | ✅ IOT | OK |

## Impacto

### Antes (Flapping)
- Dispositivos IoT conectados a "Mega_2.4G_A2DF" o "Mega_5G_A2DF" saltaban entre VLAN LAN y VLAN IoT
- Conflictos de DHCP y reconexiones cada 30-60 segundos
- RE220, sensores inteligentes, etc. con reconexiones constantes

### Después (Normal)
- Dispositivos IoT permanecen en VLAN IoT (br-lan.8) correctamente
- DHCP leases estables
- Logs limpios (sin reconexiones anormales)

## Corrección Aplicada (2026-04-24 ~15:00 UTC)

```bash
uci set wireless.guest2g.network='IOT'    # Mega_2.4G_A2DF
uci set wireless.guest5g.network='IOT'    # Mega_5G_A2DF
uci commit wireless
wifi reload
```

## Verificación Post-Corrección

✅ Ambos SSIDs ahora en IOT  
✅ Actividad DHCP normal en br-lan.8  
✅ Sin flapping detectado en los últimos 5 minutos  
✅ Dispositivos IoT con DHCP leases estables  

## Causa Raíz

La configuración UCI wireless tenía:
```
wireless.guest2g.network='lan'      # Error en guest2g (Mega_2.4G_A2DF)
wireless.guest5g.network='lan'      # Error en guest5g (Mega_5G_A2DF)
```

Debería haber sido:
```
wireless.guest2g.network='IOT'      # Correcto
wireless.guest5g.network='IOT'      # Correcto
```

## Dispositivos Afectados Anteriormente

- **RE220** (repetidor) — Reconexiones frecuentes en br-lan.8
- **TL-WA850RE** (repetidor) — Saltaba entre redes
- Otros sensores/dispositivos IoT conectados a SSIDs Mega

Todos ahora con comportamiento normal.

## Notas

- La validación anterior (2026-04-24) mostró configuración aparentemente correcta en texto, pero la realidad en UCI era diferente
- El error probablemente vino de la creación inicial de los SSIDs o durante cambios de configuración anteriores
- Ahora está en línea con la topología de red esperada: Mega = IOT VLAN

## Verificación Futura

Si el flapping reaparece, revisar:
```bash
uci show wireless | grep -E "network.*=|ssid.*="
```

Debe mostrar todos los SSIDs Mega con `network='IOT'`
