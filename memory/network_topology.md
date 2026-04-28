# Red doméstica - topología actual

**Type:** project
**Description:** Topología completa de la red doméstica con routers, repetidores y VLANs

---

## Routers

### Flint-2 (GL-MT6000, MT7986)
- Router principal
- IP: 192.168.10.1
- SSH: root con llave ed25519
- Ubicación: planta alta
- WAN: PPPoE (~350 Mbps) + WAN secundaria via lan1 (192.168.100.x, Starlink/otro ISP)
- VLAN LAN: 192.168.10.x (br-lan.10)
- VLAN IoT: 192.168.8.x (br-lan.8)
- SSIDs:
  - "AXTEL XTREMO" (5GHz)
  - "Mega_5G_A2DF" (5GHz guest)
  - "Mega_2.4G_A2DF" (2.4GHz guest)
  - "IOT" (2.4GHz IoT)
- Canales: 5GHz ch 149 (centro 155, 80MHz), 2.4GHz ch 6

### Beryl AX (GL-MT3000, MT7981)
- Modo: AP mode, backhaul Ethernet
- IP: 192.168.10.2
- SSH via ProxyJump desde Flint-2
- Ubicación: planta baja
- SSIDs:
  - "AXTEL XTREMO" (5GHz ch40/42)
  - "Mega_5G_A2DF" (5GHz)
  - "Mega_2.4G_A2DF" (2.4GHz ch11)
  - "IOT" (2.4GHz)
- Conectado a Flint-2 via Ethernet (wired backhaul)

---

## Repetidores

### TL-WA850RE V7.0
- IP: 192.168.8.248 (IoT VLAN)
- MAC: 9a:48:27:0e:54:47
- Conectado a Flint-2 2.4GHz IoT (SNR 54)
- Hace ARP proxy para sus clientes
- No soporta OpenWrt (4MB flash, chipset MediaTek sin soporte)
- Monitoreado por /usr/bin/monitor/wa850_monitor.sh (cron cada 5 min)

### RE220
- IP: 192.168.8.150 (IoT VLAN)
- MAC: b6:09:21:69:5d:8d
- Conectado al Beryl Mega_5G_A2DF (SNR 34), backhaul wired via Beryl → Flint-2
- MAC bloqueada en Flint-2 (guest2g y guest5g) para forzar conexión al Beryl
- Antes tenía SNR 8 al Flint-2 — causa de disconnects IoT

---

## Software en Flint-2

- AdGuardHome en puerto 3053; dnsmasq en 53 forward a 127.0.0.1#3053
- usteer para roaming entre Flint-2 y Beryl
- mwan3 para failover WAN
- qosmate con CAKE en pppoe-wan
- Tailscale: accept-dns=false, ruta 100.64.0.0/10 en main table persistida via /etc/hotplug.d/net/30-tailscale-routes
- Scripts de monitoreo en /usr/bin/monitor/ con notificaciones Telegram
