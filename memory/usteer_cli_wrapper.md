---
name: Usteer CLI Wrapper — ubus Implementation
description: CLI wrapper para usteer usando ubus (RPC bus de OpenWrt) — binario oficial no compilado para aarch64
type: project
originSessionId: c94e4099-5998-4017-89c7-e56420c55c6c
---
# Usteer CLI Wrapper — ubus Implementation (2026-04-23)

## Problema Resuelto

**Antes**: `usteer -c` no funciona — binario CLI oficial no compilado para OpenWrt 25.12.2 aarch64
**Ahora**: Wrapper CLI que usa `ubus call usteer` (mecanismo RPC de OpenWrt)

## Solución Implementada

### Scripts Creados

| Archivo | Propósito | Ubicación |
|---------|----------|-----------|
| `usteer` | CLI wrapper con opciones --summary, --json, etc | `/usr/local/bin/usteer` |
| `usteer-simple` | Monitor en tiempo real (3 actualizaciones) | `/usr/local/bin/usteer-simple` |

### Alias en Shell

```bash
echo "alias usteer='/usr/local/bin/usteer'" >> /root/.bashrc
echo "alias usteer='/usr/local/bin/usteer'" >> /root/.profile
```

## Comandos Disponibles

```bash
# Resumen rápido
/usr/local/bin/usteer --summary
# Output: Connected: 21, Total monitoreado: ~76 clientes

# JSON completo
/usr/local/bin/usteer

# Monitor tiempo real (5 seg refresh)
/usr/local/bin/usteer-simple
```

## Cómo Funciona

1. **Daemon usteerd** escucha en ubus (RPC bus)
2. **Wrapper** ejecuta: `ubus call usteer get_clients`
3. **Output parseable** compatible ash/BusyBox
4. **Sin dependencias externas** (solo herramientas estándar)

## Estadísticas Observadas (2026-04-23)

```
🟢 Clientes conectados: 21
📍 Total monitoreado: ~76 clientes únicos
⏱️ Estado estable (sin fluctuaciones)
```

### Clientes por Router

**Flint-2 (GL-MT6000)**:
- Total: ~60 clientes en 4 SSIDs

**Beryl (GL-MT3000)**:
- Total: ~16 clientes en 4 SSIDs

## Datos JSON Disponibles (via ubus)

Cada cliente incluye:
```json
"MAC_ADDRESS": {
  "interfaz1": {
    "connected": true/false,
    "signal": -60  // RSSI en dBm
  },
  "interfaz2": {
    "connected": true/false,
    "signal": -78
  }
}
```

## Configuración Usteer (UCI)

**Parámetros actuales**:
- `enabled=1` ✅ Daemon activo
- `network=lan` → Monitorea LAN
- `band_steering=0` → No fuerza 5GHz
- `aggressiveness=1` → Nivel bajo (menos cambios)
- `roam_trigger_snr=-75dBm` → Dispara si señal < -75

**Para más sensibilidad**:
```bash
uci set usteer.usteer.roam_trigger_snr='-80'   # Más bajo = más sensible
uci set usteer.usteer.aggressiveness='2'       # 1=low, 2=medium, 3=high
uci commit usteer
/etc/init.d/usteer restart
```

## Persistencia

**Ubicación**: `/usr/local/bin/` (se copia a USB automáticamente vía backup diario)
**Supervivencia sysupgrade**: Sí (post_restore.sh restaura desde USB)

## Troubleshooting

### Verificación rápida

```bash
# ¿Daemon activo?
pidof usteerd

# ¿ubus responde?
ubus call usteer get_clients | head -5

# ¿Wrapper funciona?
/usr/local/bin/usteer --summary
```

### Si falla

```bash
# Ver logs
logread | grep -i usteer

# Reiniciar daemon
/etc/init.d/usteer restart

# Verificar config
uci show usteer
```

## Diferencia: Binario oficial vs ubus wrapper

| Aspecto | Binario oficial | Wrapper ubus |
|---------|-----------------|--------------|
| **Disponibilidad** | ❌ No compilado para aarch64 | ✅ Disponible |
| **Dependencias** | Desconocidas | Solo ubus (estándar OpenWrt) |
| **Compatibilidad** | N/A | ash/BusyBox compatible |
| **Datos** | Mismo (procede de usteerd) | Mismo (procede de usteerd) |
| **Performance** | N/A | Minimal (RPC call) |

## Notas

- El daemon `usteerd` sí está compilado y funciona perfectamente
- La información proviene de `usteerd`, no del CLI
- El CLI es solo una interfaz para acceder a los mismos datos
- Usteer simplemente necesitaba una forma de exponer los datos — ubus es lo estándar en OpenWrt
