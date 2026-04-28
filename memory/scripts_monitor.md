# Scripts de monitoreo en Flint-2

**Type:** project
**Description:** Scripts personalizados instalados en el Flint-2

---

## Directorio principal: /usr/bin/monitor/

- **wa850_monitor.sh** — monitorea TL-WA850RE (192.168.8.248), detecta offline y cambios de clientes via ARP proxy. Cron: `*/5 * * * *`
- **onhostchange.sh** — en /etc/script/, cooldown 90s, flap detection (threshold=3, silence=3600s)

## Directorio hotplug

- **/etc/hotplug.d/net/30-tailscale-routes** — agrega ruta `100.64.0.0/10 dev tailscale0` cuando tailscale0 sube

## Configuración Tailscale aplicada

- `accept-dns=false` (no sobrescribe /etc/resolv.conf)
- DNS en admin console: solo 208.67.220.220 (OpenDNS IPv4, evita IPv6 que no hay en WAN)
- Ruta 100.64.0.0/10 en main table para que router acceda a 100.100.100.100
