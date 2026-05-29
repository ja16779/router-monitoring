# Family Presence Monitor — Sistema de Detección de Presencia Familiar

## ¿Qué hace?

Detecta automáticamente cuándo los dispositivos de tu familia **llegan** o **salen** del domicilio basándose en su conexión/desconexión del WiFi. Envía notificaciones a Telegram indicando:
- 👋 Persona que llegó, hora CST, y cuánto tiempo estuvo fuera
- 🚪 Persona que salió, hora CST

## Cómo funciona

1. **Cada minuto**, el script escanea los dispositivos configurados
2. **Busca por hostname** en DHCP leases (robusto contra MACs aleatorias de iPhone)
3. **Verifica si está conectado** a WiFi (via `iw station dump` + fallback ARP/ping)
4. **Aplica grace period de 5 min** antes de declarar "salió" (evita falsos positivos)
5. **Detecta cambios de estado** y envía notificación solo si hay cambio

## Archivos del sistema

- **Configuración**: `/etc/monitor/family_devices.conf`
- **Script**: `/usr/bin/monitor/family_presence.sh`
- **Estado**: `/tmp/family_presence/` (temporal, se resetea en reboot)
- **Logs**: `/var/log/family_presence.log`
- **Cron**: Ejecuta cada minuto via `/etc/crontabs/root`

---

## Agregar/Editar dispositivos

### Formato en `/etc/monitor/family_devices.conf`

```
# NOMBRE|IDENTIFICADOR|TIPO_ID|EMOJI
# TIPO_ID: hostname = identificar por nombre DHCP
#          mac     = identificar por MAC fija
#
# Ejemplo:
Fernando|iPhone|hostname|📱
Irasema|Z-Flip6-de-Irasema|hostname|👩
```

### Pasos para agregar un dispositivo

1. **Obtener el nombre DHCP del dispositivo**:
   ```bash
   ssh root@192.168.10.1 "grep NOMBRE /tmp/dhcp.leases"
   # Output: 1776234500 aa:bb:cc:dd:ee:ff 192.168.10.xxx nombre_dispositivo ...
   ```

2. **Editar la configuración en el router**:
   ```bash
   ssh root@192.168.10.1 "vi /etc/monitor/family_devices.conf"
   ```

3. **Agregar línea**:
   ```
   Tu Mamá|mama-nombre|hostname|👩‍🦱
   ```

4. **Guardar y salir** (`:wq` en vi)

5. **El sistema detectará automáticamente** en el próximo ciclo (máx 1 minuto)

---

## Grace Period (5 minutos)

### ¿Qué es?

Si el dispositivo se desconecta brevemente (< 5 minutos), el sistema **no envía alerta de "salió"**. Cuando se reconnecta, no envía "llegó" tampoco.

### ¿Por qué es importante?

Los iPhones se desconectan brevemente por:
- WiFi Calling
- Cambio de banda (2.4GHz ↔ 5GHz)
- Roaming entre APs
- Búsqueda de red mejor

**Sin grace period**: 10-20 alertas falsas de "salió/llegó" por evento

### Comportamiento

```
18:45 - Persona se desconecta
18:46 - Se reconecta (reconexión rápida < 5 min)
        → No envía "salió" ni "llegó" (stay en estado "home")

18:45 - Persona se desconecta
18:50 - Desconectada aún (pasaron 5 min)
        → ENVÍA ALERTA 🚪 "salió"
18:52 - Reconecta
        → ENVÍA ALERTA 👋 "llegó" + tiempo fuera (7 min)
```

---

## Verificación y testing

### Ver estado actual

```bash
ssh root@192.168.10.1 "cat /tmp/family_presence/fernando_state"
# Output: home o away
```

### Ver últimos eventos en log

```bash
ssh root@192.168.10.1 "tail -20 /var/log/family_presence.log"
```

### Probar manualmente (disparar script)

```bash
ssh root@192.168.10.1 "/usr/bin/monitor/family_presence.sh"
```

### Simular salida (test de grace period)

1. **Apagar WiFi en iPhone** (Ajustes → WiFi → OFF)
2. **Esperar 5 minutos 30 segundos**
3. **Deberías recibir alerta en Telegram**: 🚪 Fernando salió
4. **Encender WiFi nuevamente**
5. **Deberías recibir alerta**: 👋 Fernando llegó (estuvo fuera: 5min)

---

## Notificaciones de Telegram

### Formato

```
👋 Fernando llegó
🕒 09:30 CST
📴 Estuvo fuera: 2h 15min
```

```
🚪 Irasema salió
🕒 18:45 CST
```

### Tokens Telegram

- **Token**: Configurado en `/etc/monitor/config.sh` (TELEGRAM_BOT_TOKEN)
- **Chat ID**: Configurado en `/etc/monitor/config.sh` (TELEGRAM_CHAT_ID)

Para cambiar dónde llegan las notificaciones, edita `/etc/monitor/config.sh` en el router.

---

## Identificación de dispositivos

### Por HOSTNAME (Recomendado para iPhone)

iPhone moderno genera MACs aleatorias. El sistema identifica por el **nombre del dispositivo** en DHCP:

```
iPhone           → hostname "iPhone"
Z-Flip6          → hostname "Z-Flip6-de-Irasema"
Samsung tablet   → hostname "SM-L310"
```

**Ventaja**: Funciona incluso si la MAC cambia cada reconexión
**Desventaja**: Requiere que el dispositivo registre su nombre en DHCP

### Por MAC (Para dispositivos con MAC fija)

Algunos dispositivos tienen MAC estática. Puedes usarlos así:

```
Tu PC|aa:bb:cc:dd:ee:ff|mac|💻
```

---

## Logs y troubleshooting

### El dispositivo siempre muestra como "away"

```bash
# 1. Verificar que está en DHCP leases
ssh root@192.168.10.1 "grep iPhone /tmp/dhcp.leases"

# 2. Verificar que está conectado a WiFi
ssh root@192.168.10.1 "iw dev phy0-ap0 station dump | head -20"

# 3. Ver logs del script
ssh root@192.168.10.1 "tail -30 /var/log/family_presence.log"
```

### No recibe notificaciones de Telegram

```bash
# 1. Verificar que los tokens están configurados
ssh root@192.168.10.1 "grep TELEGRAM /etc/monitor/config.sh"

# 2. Probar envío manual
ssh root@192.168.10.1 'curl -s -X POST \
  "https://api.telegram.org/bot$(grep TELEGRAM_BOT_TOKEN /etc/monitor/config.sh | cut -d= -f2)/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\":\"716542586\",\"text\":\"Test\",\"parse_mode\":\"HTML\"}"'
```

### El log muestra errores

```bash
# Ver últimas líneas con errores
ssh root@192.168.10.1 "grep -i error /var/log/family_presence.log | tail -10"
```

---

## Persistencia post-upgrade

Los archivos están agregados a `/etc/sysupgrade.conf`:
- `/etc/monitor/family_devices.conf`
- `/usr/bin/monitor/family_presence.sh`

Después de un `sysupgrade`, la configuración se preserva automáticamente.

---

## Limitaciones conocidas

1. **Requiere DHCP activo**: Si el dispositivo se conecta vía IP estática, no se detecta
2. **MAC aleatoria de iPhone**: Funciona por hostname, no por MAC
3. **Grace period fijo (5 min)**: No se puede ajustar sin editar el script
4. **Latencia máxima**: 1 minuto para detectar (timeout de cron)

---

## Cómo está construido

- **Lenguaje**: POSIX sh (ash compatible con OpenWrt)
- **Dependencias**: 
  - `iw` (para detectar WiFi)
  - `ping` (fallback para ARP refresh)
  - `curl` (para notificaciones Telegram)
  - `date` (para timestamps)
- **Persistencia**: Archivos planos en `/tmp/family_presence/`
- **Cron**: Cada minuto

El script es simple, robusto y se ejecuta rápido (<1 segundo por ciclo).
