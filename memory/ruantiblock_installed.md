---
name: Ruantiblock Anti-DPI Instalado
description: Daemon anti-DPI para evadir inspección profunda de paquetes (DPI) en ISP mexicanos
type: project
originSessionId: 5df9b90a-0dee-4075-a28c-7433d3d62640
---
## Instalación (2026-04-14)

**Paquetes instalados:**
- `ruantiblock-2.1.12-r3` — daemon principal
- `luci-app-ruantiblock-2.1.12-r3` — interfaz web en LuCI

**Estado:** ✅ CORRIENDO

## ¿Qué hace?

Ruantiblock detecta y elude bloqueos basados en **Deep Packet Inspection (DPI)**:

1. **Fragmentación de paquetes**: Divide paquetes grandes en fragmentos pequeños que confunden al DPI
2. **Ofuscación**: Mezcla tráfico bloqueado con datos normales
3. **Cambios de timing**: Añade retardos inteligentes entre paquetes
4. **Proxy transparente**: Redirige tráfico específico a través de Tor/VPN

## Relevancia para tu entorno

- Telmex y Megacable usan DPI para bloquear Telegram, ciertas IPs, servicios VPN
- Ruantiblock puede permitir acceso a estos servicios sin necesidad de ruteos alternativos
- Complementa la configuración actual (donde Telegram de eth1 se ruta por lan1)

## Acceso a configuración

**Interfaz web (LuCI):**
```
URL: http://192.168.10.1:3000/cgi-bin/luci/admin/network/ruantiblock
Usuario: root
Contraseña: admin
```

**Modo proxy actual:** `1` (Tor)

## Problemas conocidos

**⚠️ Blacklist no se descarga automáticamente:**
- Error: "Blacklist update error"
- Causa: Las listas en línea no se descargan correctamente
- Solución:
  ```sh
  ssh root@192.168.10.1
  /usr/bin/ruantiblock force-update      # Forzar actualización
  /etc/init.d/ruantiblock restart        # Reiniciar servicio
  ```

Si persiste: configurar directamente en LuCI seleccionando tipo de lista y ejecutar actualización manualmente.

## Comandos útiles

```sh
# Estado
/usr/bin/ruantiblock status

# Actualizar listas
/usr/bin/ruantiblock force-update

# Servicio
/etc/init.d/ruantiblock {start|stop|restart|reload}

# Ver logs
logread | grep ruantiblock | tail -20
```

## Configuración UCI

**Ubicación:** `/etc/config/ruantiblock`

**Parámetros principales:**
- `proxy_mode=1` — Tor proxy mode
- `proxy_local_clients=1` — Aplicar a tráfico local del router
- `bllist_preset=1` — Usar preset de lista de bloqueo
- `update_at_startup=1` — Descargar listas al iniciar
- `enable_logging=1` — Registrar en syslog

## Próximos pasos

1. **Verificar descarga de listas** — intenta `force-update` si no se descargan automáticamente
2. **Configurar desde LuCI** — seleccionar qué servicios (Telegram, DNS) quieres evitar con DPI evasion
3. **Probar con Telegram** — verificar si Telegram ahora funciona desde eth1 sin necesidad de redirigir a lan1
4. **Monitorear rendimiento** — ruantiblock añade overhead; monitorear latencia/ancho de banda

## Historial

- **2026-04-14**: Instalado ruantiblock-2.1.12-r3. Servicio corriendo pero listas sin descargar. Configuración en UCI lista para personalizar desde LuCI.
