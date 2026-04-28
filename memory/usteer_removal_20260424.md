---
name: Usteer Desinstalación Completa (2026-04-24)
description: Usteer desintalado y reemplazado con SSID adicional de 2.4GHz para mejor cobertura
type: project
originSessionId: c94e4099-5998-4017-89c7-e56420c55c6c
---
# Usteer Removal — Completado 2026-04-24

## Cambio Realizado

**Usuario**: Desinstalación de usteer + Agregación de SSID adicional 2.4GHz (mejor cobertura en cuartos)

**Razón**: Usteer proporciona WiFi steering automático, pero se eligió reemplazarlo con una SSID adicional de 2.4GHz para mejor cobertura física en áreas donde no llegaba bien la señal.

## Estado Final (2026-04-24)

### Flint-2
- **Daemon usteerd**: ❌ Removido (matado PID 18696, 2026-04-24 14:30 UTC)
- **Paquete**: ❌ No instalado
- **Autostart**: ❌ Sin referencias en cron/init.d
- **Referencias en scripts**: ⚠️ Presentes en `/etc/script/post_openwrt25.sh`, `post_upgrade25.sh` (se ejecutarían en sysupgrade)

### Beryl
- **Daemon**: ❌ Removido (nunca fue AP routing)
- **Autostart**: ✅ Limpio

## WiFi Networks Actuales (2026-04-24)

### Flint-2 (5 SSIDs)
1. **AXTEL XTREMO** (5GHz, phy1-ap0)
2. **AXTEL XTREMO** (2.4GHz, phy0-ap0) ← **NUEVA**
3. **Mega_5G_A2DF** (5GHz, phy1-ap1)
4. **Mega_2.4G_A2DF** (2.4GHz, phy0-ap1)
5. **IOT** (2.4GHz, phy0-ap2)

### Beryl (5 SSIDs)
1. **AXTEL XTREMO** (5GHz)
2. **AXTEL XTREMO** (2.4GHz) ← **NUEVA**
3. **Mega_5G_A2DF** (5GHz)
4. **Mega_2.4G_A2DF** (2.4GHz)
5. **IOT** (2.4GHz)

## Impacto

### ✅ Ventajas de Agregar SSID 2.4GHz
- Mayor cobertura física en cuartos (frecuencia 2.4GHz tiene mejor penetración de paredes)
- Banda separada reduce congestión
- Clientes pueden elegir manualmente la mejor red

### ⚠️ Pérdida de Funcionalidad (sin Usteer)
- **Sin WiFi steering automático**: Clientes no roamean automáticamente entre APs
- **Sin roaming inteligente**: Los dispositivos se quedan conectados a AP con señal débil
- **Usuario debe seleccionar manualmente**: Configurar en dispositivo qué SSID usar

### 📊 Compensación
La cobertura física mejorada (2.4GHz) compensa la falta de steering automático en la mayoría de casos.

## Acción Requerida en Sysupgrade

Si se hace **sysupgrade** en el futuro, los scripts de post-restauración intentarán reinstalar usteer automáticamente:

```bash
# Para evitar reinstalación futura:
ssh root@192.168.10.1 "sed -i '/usteer/d' /etc/script/post_openwrt25.sh /etc/script/post_upgrade25.sh"
```

**Ubicaciones con referencias a usteer** (inactivas ahora, se activarían en restauración):
- `/etc/script/post_openwrt25.sh` — Intenta configurar usteer (línea 6)
- `/etc/script/post_upgrade25.sh` — Intenta instalar usteer
- `/etc/script/post_upgrade_flint2.sh` — Intenta instalar `luci-app-usteer`
- `/etc/script/roaming_monitor.sh` — Monitor de roaming que usa `ubus call usteer`

## Cómo Verificar Estado

```bash
# Confirmar que está removido
pidof usteerd
# Debe retornar nada (sin PID)

# Confirmar en router-check
ssh root@192.168.10.1 "pidof usteerd 2>/dev/null && echo 'INSTALLED' || echo 'REMOVED'"
# Debe retornar: REMOVED
```

## Próximos Pasos (Opcional)

Si la cobertura sigue siendo insuficiente en algunos cuartos:
1. Revisar posicionamiento de antenas
2. Considerar repetidor adicional (RE220) en ese cuarto
3. O reinstalar usteer si se requiere WiFi steering automático

## Historial

| Fecha | Acción | Status |
|-------|--------|--------|
| 2026-04-23 | Usuario desinstala usteer + agrega SSID 2.4GHz | Completado |
| 2026-04-24 14:30 UTC | Matar proceso usteerd huérfano (PID 18696) | ✅ Completado |
| 2026-04-24 14:35 UTC | Verificar autostart y referencias | ✅ Limpio |
