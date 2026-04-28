# Acceso SSH a routers

**Type:** user
**Description:** Credenciales y métodos de acceso SSH a los routers

---

## Flint-2
- Host: 192.168.10.1
- Usuario: root
- Auth: llave ed25519 (ya autorizada en /etc/dropbear/authorized_keys)

## Beryl AX
- Host: 192.168.10.2
- Usuario: root
- Acceso: via ProxyJump — `ssh -J root@192.168.10.1 root@192.168.10.2`
- Auth: llave ed25519 autorizada
- IMPORTANTE: NO usar BusyBox SSH del Flint-2 como cliente (falla con "Interrupted")

## Notas adicionales
- Interfaces WiFi en Beryl AX: wlan0, wlan0-1, wlan1, wlan1-1 (NO phy0-ap0 como el Flint-2)
- Telegram bot token y chat ID están en /etc/monitor/config.sh y /usr/bin/monitor/config.sh
