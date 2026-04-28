---
name: DNS over TLS — Arquitectura actual NextDNS
description: Pipeline DNS (2026-04-13): dnsmasq:53 → AGH:3053 → NextDNS DoT (47a69f). IoT bypass directo a 1.1.1.1
type: project
originSessionId: 5df9b90a-0dee-4075-a28c-7433d3d62640
---
## Arquitectura DNS actual (2026-04-13)

```
LAN/WiFi clientes
   ↓
dnsmasq:53  (DNS + DHCP, /etc/dnsmasq.conf, cachesize 10000)
   ↓ server=127.0.0.1#3053
AdGuardHome:3053  (filtrado, caché 16MB, DNSSEC, web UI :3000)
   ↓ upstream DoT (puerto 853 TCP)
tls://47a69f.dns.nextdns.io  (NextDNS, perfil 47a69f)

IoT clientes (br-lan.8 / 192.168.8.0/24)
   ↓ nftables dstnat_iot intercepta :53
1.1.1.1:53  (Cloudflare, sin filtros AGH)
   + DHCP option 6 → 1.1.1.1, 8.8.8.8
```

## Configuración dnsmasq

**Archivo**: `/etc/dnsmasq.conf` (incluido via conf-file en runtime config)

```
server=127.0.0.1#3053
```

**Nota**: La opción UCI `list server` no se vuelca al runtime config en esta versión. El upstream se configura directamente en `/etc/dnsmasq.conf`.

UCI mantiene `noresolv='1'` y `server='127.0.0.1#3053'` (documentación), pero la efectividad real viene del archivo conf.

## Configuración AdGuardHome — `/etc/adguardhome/adguardhome.yaml`

```yaml
dns:
  port: 3053
  upstream_dns:
    - tls://47a69f.dns.nextdns.io
  bootstrap_dns:
    - 45.90.28.0
    - 45.90.30.0
  fallback_dns:
    - tls://45.90.28.0
    - tls://45.90.30.0
  upstream_mode: load_balance
  cache_enabled: true
  cache_size: 16777216
  cache_ttl_min: 300
  cache_ttl_max: 3600
  cache_optimistic: true
  enable_dnssec: true
```

**Directorios de datos** (movidos a overlay para persistencia):
- querylog: `/etc/adguardhome/data/querylog`
- statistics: `/etc/adguardhome/data`
- work-dir: `/var/lib/adguardhome`

**Problema conocido**: `/var/lib/adguardhome/data/querylog` se borra en cada reboot (está en RAM). El init.d de AGH lo recrea, pero necesita que el directorio exista. Los datos de querylog ahora están en `/etc/adguardhome/data/querylog` (persistent overlay).

## IoT DNS Bypass

### Via nftables (chain dstnat_iot)
```
chain dstnat_iot {
    meta nfproto ipv4 udp dport 53 dnat ip to 1.1.1.1:53  # IoT DNS redirect UDP
    meta nfproto ipv4 tcp dport 53 dnat ip to 1.1.1.1:53  # IoT DNS redirect TCP
}
```

**Persistencia**: UCI firewall redirect (no en firewall.user):
```sh
uci show firewall | grep -E 'IoT DNS'
# Zona: iot, proto: udp/tcp, src_dport: 53, dest_ip: 1.1.1.1, target: DNAT
```

### Via DHCP option 6
```
dhcp.iot.dhcp_option='6,1.1.1.1,8.8.8.8'
```
DHCP IoT en `/etc/config/dhcp`: interface IOT, range 100-249, lease 24h.

## WAN (actualizado 2026-04-13)

PPPoE eliminado. WAN ahora es **DHCP client** directo:
```
network.wan.proto='dhcp'
network.wan.device='eth1'
```

## NextDNS

- **ID perfil:** `47a69f`
- **Upstream DoH:** `https://dns.nextdns.io/47a69f`
- **Bootstrap (anycast):** `45.90.28.0` / `45.90.30.0`
- **Fallback DoT:** `tls://45.90.28.0` / `tls://45.90.30.0`
- **IPs dedicadas (fallback legacy):** `45.90.28.75` / `45.90.30.75`
- **Linked IP URL:** `https://link-ip.nextdns.io/47a69f/bd93c0cf8bbe6f81`
- **Dashboard:** `my.nextdns.io`

## Caché DNS (doble capa)

1. **dnsmasq** — 10,000 entradas, TTL heredado de AGH
2. **AdGuardHome** — 16MB, TTL 5min–1h, modo optimista

## Historial de arquitecturas

| Fase | Descripción |
|---|---|
| Fase 1 | AGH:53 → Unbound:5335 → upstreams estáticos |
| Fase 2 | AGH:53 → dnsmasq:54 → DoT upstreams (OpenDNS) |
| Fase 3 | dnsmasq:53 → AGH:3053 → NextDNS DoT |
| Fase 4 (actual) | dnsmasq:53 → AGH:3053 → NextDNS DoH. IoT bypass directo a 1.1.1.1 |
