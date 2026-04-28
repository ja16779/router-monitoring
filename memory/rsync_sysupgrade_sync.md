---
name: Rsync Sysupgrade Sync — Sincronización con rsync
description: Script de sincronización rsync de archivos en sysupgrade.conf hacia USB, sin tar
type: project
originSessionId: 3ab63c79-a102-4073-9eb2-7c72eb994852
---
## Rsync Sysupgrade Sync

**Ubicación**: `/usr/bin/monitor/rsync_sysupgrade_sync.sh`

**Versión**: v2 (Smart Sync — 2026-04-17 13:15 UTC)

**Paquetes requeridos**: `apk add rsync` (instalado 2026-04-17)

**Crontab**: `23 */6 * * * /usr/bin/monitor/rsync_sysupgrade_sync.sh`
- Ejecuta cada 6 horas (00:23, 06:23, 12:23, 18:23 UTC)
- **Optimización**: Solo sincroniza si detecta cambios
- Hora local México City: -6 horas (18:23, 00:23, 06:23, 12:23 CST)

## Funcionalidad

El script sincroniza **todos los archivos y directorios** listados en `/etc/sysupgrade.conf` hacia `/mnt/usb/rsync-backups/sysupgrade-sync` usando rsync.

**Smart Sync (v2) — Optimización de cambios**:
- ✅ **Detecta cambios antes de sincronizar** (MD5 hash)
- ✅ Solo ejecuta rsync si hay cambios reales
- ✅ Si sin cambios → se salta rsync (muy rápido)
- ✅ Si hay cambios → sincroniza solo lo modificado
- ✅ Opción `--force` para forzar sincronización si se necesita

**Diferencia con tar**:
- ✅ Rsync solo copia **cambios** (no todo cada vez)
- ✅ Mantiene **estructura original** (preserva rutas relativas)
- ✅ Conserva **permisos y metadatos**
- ✅ Permite **sincronización incremental**
- ✅ Genera **estadísticas detalladas**

## Items Sincronizados (24 total)

**Cambio 2026-04-17 13:10**: Se removieron referencias de crowdsec y banip que no estaban en uso.

```
Configuración:
  ✅ /etc/config/           (mwan3, unbound, ddns, etc.)
  ✅ /etc/crontabs/         (tareas programadas)
  ✅ /etc/hotplug.d/        (scripts de eventos del sistema)
  ✅ /etc/init.d/           (servicios)
  ✅ /etc/monitor/          (configuración de monitoreo)
  ✅ /etc/mwan3.user        (MWAN3 custom rules)
  ✅ /etc/nftables.d/       (firewall custom)
  ✅ /etc/script/           (scripts personalizados)
  ✅ /etc/sysctl.d/         (kernel tuning)

Aplicaciones:
  ✅ /etc/adguardhome/      (AdGuardHome config)
  ✅ /etc/unbound/          (Unbound config + auth-zones)

SSH y Seguridad:
  ✅ /root/.ssh/            (claves SSH)
  ✅ /root/.config/         (configs globales)

Servicios:
  ✅ /usr/bin/monitor/      (scripts de monitoreo)
  ✅ /etc/init.d/agh-preinit (pre-init de AGH)

DNS:
  ✅ /var/lib/unbound/      (auth-zones: root.zone, arpa.zone, etc.)

⚠️ Items NO encontrados (ignorados):
  - /etc/hotplug.d/dhcp/50-sync-beryl

🗑️ Items REMOVIDOS (2026-04-17):
  - /etc/config/crowdsec (no instalado)
  - /etc/config/banip (no instalado)
  - /etc/crowdsec/ (datos obsoletos)
  - /srv/crowdsec/ (bases de datos obsoletas)
```

## Estadísticas de Ejecución

**Antes de limpieza (2026-04-17 13:09)**:
```
Items procesados: 28
Sincronizados: 25 ✅
Errores: 0
Tamaño total: 91.6M (incluye crowdsec 67MB)
```

**Después de limpieza (2026-04-17 13:10)**:
```
Items procesados: 24
Sincronizados: 23 ✅
Errores: 0
Tamaño total: 91.6M (sin crowdsec/banip en sistema)
```

*Nota: El tamaño USB se mantiene igual porque rsync preserva datos históricos. En próximas sincronizaciones será más rápido.*

## Uso Manual

```bash
# Verificar cambios y sincronizar si es necesario (Smart Sync)
ssh root@192.168.10.1 /usr/bin/monitor/rsync_sysupgrade_sync.sh

# Forzar sincronización completa (ignore si hay cambios)
ssh root@192.168.10.1 /usr/bin/monitor/rsync_sysupgrade_sync.sh --force

# Ver logs
ssh root@192.168.10.1 tail -50 /var/log/rsync_sysupgrade_sync.log

# Ver resumen de última sincronización
ssh root@192.168.10.1 cat /mnt/usb/rsync-backups/sysupgrade-sync/.sync_summary

# Ver estado del hash (para debugging)
ssh root@192.168.10.1 cat /tmp/rsync_sysupgrade.hash
```

## Archivos de Estado

| Archivo | Propósito | Ubicación |
|---------|-----------|-----------|
| `rsync_sysupgrade_sync.log` | Logs de ejecución | `/var/log/` |
| `.sync_summary` | Resumen de última sincronización | `/mnt/usb/rsync-backups/sysupgrade-sync/` |
| `rsync_sysupgrade.hash` | MD5 hash para detección de cambios | `/tmp/` |

**Cómo funciona la detección de cambios**:
1. Script calcula hash MD5 de metadatos de todos los archivos en sysupgrade.conf
2. Compara con hash anterior guardado en `/tmp/rsync_sysupgrade.hash`
3. Si hashes son iguales → **sin cambios, salta rsync**
4. Si hashes difieren → **cambios detectados, ejecuta rsync**
5. Después de rsync exitoso → actualiza hash para próxima comparación

## Características

### Modo Check-Only (--check-only)
- Simula la sincronización sin hacer cambios
- Útil para verificar qué se va a sincronizar
- No modifica nada en el destino

### Modo Verbose (--verbose)
- Muestra cada archivo procesado en tiempo real
- Útil para debugging
- Genera más output en logs

### Notificaciones Telegram
Si `/etc/monitor/config.sh` tiene `TG_BOT_TOKEN` y `TG_CHAT_ID` configurados:
- Envía notificación después de cada sincronización (excepto check-only)
- Incluye estadísticas: items procesados, sincronizados, errores, tamaño
- Alerta diferente si hay errores

**Ejemplo de mensaje**:
```
📦 Rsync Sync Completado ✅ EXITOSO

Items procesados: 28
Sincronizados: 25
Errores: 0
Tamaño: 91.6M

Destino: /mnt/usb/rsync-backups/sysupgrade-sync
Fecha: 2026-04-17 13:09:04
```

## Ventajas de Rsync vs Tar

| Aspecto | Rsync | Tar |
|---------|-------|-----|
| **Cambios incrementales** | ✅ Solo copia cambios | ❌ Copia todo siempre |
| **Compresión** | Opcional (-z) | Automática (.tar.gz) |
| **Estructura original** | ✅ Preserva rutas | ❌ Comprime en archivo |
| **Facilidad de recuperación** | ✅ Acceso directo a archivos | ❌ Necesita extraer primero |
| **Velocidad en cambios pequeños** | ✅ Muy rápido | ❌ Lento |
| **Metadatos y permisos** | ✅ Preserva todos | ✅ Preserva todos |

## Configuración en Crontab

```
23 */6 * * * /usr/bin/monitor/rsync_sysupgrade_sync.sh
```

- **Minuto**: 23 (para evitar minuto 0, evita contención de cron)
- **Hora**: */6 (cada 6 horas: 00:23, 06:23, 12:23, 18:23 UTC)
- **Día**: * (todos los días)
- **Mes**: * (todos los meses)
- **Día de semana**: * (todos los días)

## Espacio en USB

```
Tamaño de sincronización: 91.6M
Localización: /mnt/usb/rsync-backups/sysupgrade-sync/
```

**Nota**: El directorio `/srv/crowdsec/` (67MB) es el mayor. Se puede excluir si no se necesita CrowdSec.

## Troubleshooting

### Error: "rsync no está instalado"
```bash
ssh root@192.168.10.1 apk add rsync
```

### Permisos insuficientes
```bash
ssh root@192.168.10.1 chmod 755 /mnt/usb/rsync-backups/
```

### Destino lleno
```bash
ssh root@192.168.10.1 du -sh /mnt/usb/rsync-backups/sysupgrade-sync/
```

### Verificar logs detallados
```bash
ssh root@192.168.10.1 /usr/bin/monitor/rsync_sysupgrade_sync.sh --verbose
```

## Próximos Pasos Recomendados

1. **Automatizar en Beryl**: Considerar sincronizar también configuración del Beryl a USB
2. **Compresión remota**: Opción de comprimir incrementalmente con gzip
3. **Rotación de backups**: Mantener múltiples versiones (daily, weekly, monthly)
4. **Verificación de integridad**: Agregar hash para verificar que no se corrompió la sincronización

## Ejemplos de Ejecución

**Ejemplo 1: Primera ejecución (detecta cambios)**
```
[2026-04-17 13:15:31] Modo: SMART (solo cambios)
[2026-04-17 13:15:32] Hash actual: 68b329da... | Hash anterior: ...
[2026-04-17 13:15:32] 🔄 Cambios detectados — ejecutando rsync completo...
[2026-04-17 13:15:34] ✅ Sincronización exitosa
[2026-04-17 13:15:34] Estadísticas: Number of files: 204 (reg: 156, dir: 47, link: 1)
```
Resultado: Se sincronizó (había cambios)

**Ejemplo 2: Segunda ejecución sin cambios (skip)**
```
[2026-04-17 13:15:37] Modo: SMART (solo cambios)
[2026-04-17 13:15:38] Hash actual: 68b329da... | Hash anterior: 68b329da...
[2026-04-17 13:15:38] ✅ Sin cambios detectados — sincronización SALTADA
```
Resultado: No ejecutó rsync (sin cambios) — **muy rápido** ⚡

**Ejemplo 3: Forzar sincronización**
```
[2026-04-17 13:15:42] Modo: FORCE
[2026-04-17 13:15:45] 🔄 Cambios detectados — ejecutando rsync completo...
[2026-04-17 13:15:45] ✅ Sincronización exitosa
```
Resultado: Se forzó sincronización con `--force`

## Historial de Cambios

| Fecha | Cambio |
|-------|--------|
| 2026-04-17 13:09 | Script v1 creado e instalado |
| 2026-04-17 13:09 | rsync instalado (v3.4.1-r3) |
| 2026-04-17 13:09 | Crontab configurado (cada 6 horas) |
| 2026-04-17 13:15 | Script v2 — Smart Sync con detección de cambios |
| 2026-04-17 13:15 | Pruebas exitosas: skip sin cambios, force funciona |
