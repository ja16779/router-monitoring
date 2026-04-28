# Flint 2 (GL-MT6000) - Referencia de configuracion para migracion a OpenWrt 25.12

Backup completo: `backup-glinet-full.tar.gz` (44.7 MB)
Fecha: 2026-03-03

---

## 1. RED / NETWORK

### WAN (PPPoE)
- Device: `eth1.881` (VLAN 881 sobre eth1)
- Proto: PPPoE
- Usuario: `44F436LZTEG245294E1@prodigyweb.com.mx`
- Password: `35c99937079a91bdeab8c848191d94`
- MTU: 1492
- Keepalive: 10 6
- IPv6: deshabilitado

### LAN (VLAN 10)
- Device: `br-lan.10`
- IP: 192.168.10.1/24
- DNS: 127.0.0.1 (local - AdGuard Home)
- Puertos fisicos: lan2, lan4:t (trunk), lan5:t (trunk)

### IOT (VLAN 8)
- Device: `br-lan.8`
- IP: 192.168.8.1/24
- DNS: 127.0.0.1
- Puertos fisicos: lan3, lan4:t (trunk), lan5:t (trunk)

### Bridge br-lan
- MAC: 94:83:c4:a6:3b:d9
- Puertos: lan2, lan3, lan4, lan5
- VLAN filtering: habilitado

### Bridge VLANs
```
VLAN 8:  lan3, lan4:t, lan5:t
VLAN 10: lan2, lan4:t, lan5:t
```

### WAN Device
```
eth1.881 (802.1Q VLAN 881 sobre eth1)
```

### Second WAN
- Device: lan1 (puerto fisico)
- Proto: DHCP
- Metric: 2

### Guest (deshabilitado)
- Device: br-guest
- IP: 192.168.9.1/24

---

## 2. WIRELESS

### Radio 0 (2.4 GHz)
- Band: 2g
- Channel: 6
- HTMode: HE20 (WiFi 6)
- Country: MX
- TxPower: 20

### Radio 1 (5 GHz)
- Band: 5g
- Channel: 44
- HTMode: HE80 (WiFi 6)
- Country: MX
- Channels: 36,40,44,48,149,153,157,161

### SSIDs

| SSID | Band | Red | 802.11r | Notas |
|------|------|-----|---------|-------|
| AXTEL XTREMO | 5 GHz (wifi5g) | lan | Si (domain 123F) | Principal |
| AXTEL XTREMO | 2.4 GHz (wifinet4) | lan | Si (domain 123F) | Deshabilitado |
| Mega_2.4G_A2DF | 2.4 GHz (guest2g) | IOT | No | IOT 2.4G |
| Mega_5G_A2DF | 5 GHz (guest5g) | IOT | Si (domain 123F) | IOT 5G |
| IOT | 2.4 GHz (wifinet3) | IOT | No | IOT dedicado |

### Claves WiFi
- Todas usan: `Axtel200`
- Encryption: psk2 (5G), psk-mixed (2.4G)

### 802.11r (Fast Roaming)
- Mobility domain: 123F
- ft_over_ds: 1
- ft_psk_generate_local: 1
- 802.11k: habilitado

---

## 3. FIREWALL

### Zonas
| Zona | Input | Output | Forward | Networks | Masq |
|------|-------|--------|---------|----------|------|
| lan | ACCEPT | ACCEPT | ACCEPT | lan | No |
| wan | DROP | ACCEPT | DROP | wan, wan6, wwan, secondwan, tethering | Si |
| guest | ACCEPT | ACCEPT | ACCEPT | guest | Si |
| wgserver | ACCEPT | ACCEPT | ACCEPT | wgserver | Si |
| iot | ACCEPT | ACCEPT | DROP | IOT | No |

### Forwarding
| Src | Dest | Notas |
|-----|------|-------|
| lan -> wan | Internet para LAN |
| guest -> wan | Internet para guest |
| wgserver -> wan | Internet para WG clients |
| lan -> wgserver | LAN accede a WG |
| iot -> wan | Internet para IOT |
| lan -> iot | LAN accede a IOT |

### WireGuard
- Puerto: 51820 (abierto desde wan)
- wgserver2lan: ACCEPT (WG clients acceden a LAN)
- wgserver2wgserver: REJECT (clientes no se ven entre si)

### DNS Leak Protection (reglas activas)
```
lan_drop_leaked_dns:     src=lan,  udp/53,  mark !0x8000/0xf000 -> DROP
lan_drop_leak_adgdns:    src=lan,  udp/3053, mark 0x0/0xf000 -> DROP
wgserver_drop_leaked_dns: src=wgserver, udp/53, mark !0x8000/0xf000 -> DROP
wgserver_drop_leaked_adgdns: src=wgserver, udp/3053, mark 0x0/0xf000 -> DROP
iot_drop_leaked_dns:     src=iot,  udp/53,  mark !0x8000/0xf000 -> DROP
iot_drop_leak_adgdns:    src=iot,  udp/3053, mark 0x0/0xf000 -> DROP
```

### Custom nftables (ruleset-post/)

**dns_accept.nft:**
```nft
add chain inet fw4 dns_accept
add rule inet fw4 dns_accept tcp dport 53 meta mark and 0x0000f000 == 0x00008000 accept
add rule inet fw4 dns_accept udp dport 53 meta mark and 0x0000f000 == 0x00008000 accept
insert rule inet fw4 input iifname { br-*, ovpnserver, wgserver } jump dns_accept
add rule inet fw4 dns_accept tcp dport 3053 meta mark and 0x0000f000 != 0x0 accept
add rule inet fw4 dns_accept udp dport 3053 meta mark and 0x0000f000 != 0x0 accept
```

**tcp_dns_leak_drop.nft:**
```nft
insert rule inet fw4 output ip protocol tcp meta skuid 453 meta mark & 0x0000f000 == 0x00000000 counter drop
```

### Firewall includes
- `/etc/firewall.nat6` (reload)
- `/etc/firewall.dns_order` (script, reload)
- `/etc/firewall.security` (script, no reload)
- `/etc/firewall.dmz.exclude` (script, reload)
- `/usr/bin/gl_block.sh` (script, reload)

---

## 4. DHCP / DNS

### dnsmasq (instance_lan)
- Interfaces: IOT, lan
- DNS upstream: 127.0.0.1#3053 (AdGuard Home)
- noresolv: 1 (no usar /etc/resolv.conf)
- filter_aaaa: 1
- sequential_ip: 1
- leasefile: /tmp/dhcp.leases
- dhcpleasemax: 300
- dnsforwardmax: 150
- cachesize_old: 0

### DHCP pools
| Interface | Start | Limit | Lease | DHCP Option |
|-----------|-------|-------|-------|-------------|
| lan | 100 | 150 | 72h | 42,192.168.10.1 (NTP) |
| IOT | 100 | 150 | 72h | 42,192.168.8.1 (NTP) |

### Reservaciones DHCP
| MAC | IP | Nombre |
|-----|-----|--------|
| 00:15:99:88:7C:28 | 192.168.8.144 | - |
| 94:83:C4:5F:53:0A | 192.168.8.101 | - |
| 0C:DC:91:37:35:13 | 192.168.8.248 | Echo-Pop |
| 7C:B9:4C:C8:C1:1D | 192.168.8.201 | FCOMEDOR |
| 7C:B9:4C:C8:A3:53 | 192.168.8.239 | FTV |
| 24:94:94:98:06:55 | 192.168.8.236 | FESCALERA |

### DNS domains
| Name | IP |
|------|-----|
| console.gl-inet.com | 192.168.8.1 |
| Sala | 192.168.10.2 |
| Principal_Vlan10 | 192.168.10.1 |

---

## 5. WIREGUARD SERVER

- Private key: `IB9pGQAmgyKye3H3IigJfvIRpC3cEIJ3xKUC4XsGZmA=`
- Public key: `XH3LqC3FMWM/Aggah7lIhHnyWijx1weiHLlOQp7dRiQ=`
- Address: 10.0.0.1/24
- Port: 51820
- fwmark: 0x8000

### Peers
| Name | Public Key | Client IP |
|------|-----------|-----------|
| Iphone | QyNkDKQX4PaDjs7kc1cv6+DT6xPudgOYB7yKzRQcE08= | 10.0.0.2 |
| Laptop | 9zILqOiijC/JHu8TmzQCaB3SHCFM4JLhEPfrADlpbHk= | 10.0.0.3 |
| Router_remoto | Hin5B57mIQFhE4O7joijg5gAOQWEL89SSEoIz8+cSzM= | 10.0.0.4 |
| IPHONE | coY5mI/xAvVGEUqHRas11cMmUAYE9qKOsjIdGkZy8W8= | 10.0.0.5 |

> NOTA: En OpenWrt vanilla, WireGuard se configura como interface proto 'wireguard'
> en lugar de 'wgserver'. Necesitaras recrear la config manualmente.

---

## 6. QoSmate

- WAN interface: pppoe-wan
- Uprate: 350000 kbps
- Downrate: 350000 kbps
- Root qdisc: CAKE
- CAKE settings: diffserv4, host isolation, NAT ingress/egress, ack-filter auto
- MSS: 1452
- Link preset: pppoe-ptm
- WASH DSCP down: 1 (up: 0)

---

## 7. AdGuard Home

- Escucha en puerto 3053 (dnsmasq le reenvía)
- Config en: `/etc/AdGuardHome/agh-backup/AdGuardHome.yaml`
- Backup en USB: `/tmp/mountd/disk2_part1/etc/AdGuardHome/agh-backup/`

---

## 8. mdns-repeater

```
config mdns_repeater 'main'
    list interface 'br-lan.8'
    list interface 'br-lan.10'
```

---

## 9. SISTEMA

- Hostname: GL-MT6000
- Timezone: CST6 (America/Monterrey)
- Syslog remoto: logs3.papertrailapp.com:52356 (UDP)
- NTP server: habilitado

---

## 10. CRONTAB

```
*/5 * * * * /usr/bin/monitor/monitor_internet.sh
*/5 * * * * /usr/bin/monitor/monitor_servicios.sh
*/15 * * * * /usr/bin/monitor/monitor_red.sh
*/30 * * * * /usr/bin/lua /usr/share/gl-update-cable-mac.lua time
*/30 * * * * /usr/bin/monitor/traffic_accounting.sh update
*/5 * * * * /usr/bin/monitor/monitor_sistema.sh
0 * * * * /etc/script/dns.sh
0 * * * * /usr/bin/monitor/monitor_seguridad.sh
0 0 * * * /etc/script/contrack.sh
0 0 * * * /etc/script/mega.sh && rm /tmp/dhcpmasq.log
0 0 * * * /etc/script/telmexperf.sh
0 0 * * * /usr/bin/monitor/mac_report.sh
0 0 * * * /usr/bin/monitor/reporte_medianoche.sh
0 0 * * * > /tmp/dnsmasq.log
0 0 * * * > /var/log/messages && dmesg -c > /dev/null 2>&1
0 0 */3 * * /etc/script/backup_new.sh && /etc/script/adguard.sh
0 1 * * * /etc/script/megaperf.sh
0 3 * * 0 /usr/bin/monitor/log_cleaner.sh
0 3 * * 7 /etc/script/reboot.sh
0 7 * * * /usr/bin/monitor/reporte_diario.sh
0 8 * * 1 /etc/script/check_firmware.sh
0 8 * * 0 /usr/bin/monitor/adguard_stats.sh notify
0 9 * * * /etc/script/check_glinet.sh
10 0 * * * /usr/bin/monitor/reporte_beryl_wifi.sh
5 0 * * * /usr/bin/monitor/reporte_leases.sh
0 4 * * * /usr/bin/monitor/bufferbloat_test.sh
0 5 * * 0 /usr/bin/monitor/wifi_monitor_all.sh auto notify
0 * * * * /usr/bin/monitor/isp_tracker.sh collect
0 20 * * * /usr/bin/monitor/isp_tracker.sh notify
*/2 * * * * /etc/script/roaming_monitor.sh
```

---

## 11. PAQUETES CLAVE A INSTALAR EN OPENWRT VANILLA

### Networking
- `dnsmasq-full` (reemplaza dnsmasq por defecto)
- `wireguard-tools`, `kmod-wireguard`, `luci-proto-wireguard`
- `ppp`, `kmod-pppoe` (PPPoE)
- `kmod-tcp-bbr` (TCP BBR)

### QoS
- `kmod-sched-cake`, `tc-full`
- QoSmate (instalar desde repo)

### DNS
- AdGuard Home (binario externo)
- `bind-dig` (opcional, para diagnostico)

### WiFi
- `wpad-openssl` (802.11r, 802.11k)
- `usteer` (roaming)

### Firewall
- `firewall4`, `nftables-json` (incluidos por defecto)

### Monitoring
- `mdns-repeater`
- `conntrack`
- `iperf3`, `fping`, `tcpdump`
- `htop`, `btop`, `bmon`, `nload`, `iftop`

### Otros
- `nano-full`, `bash`
- `irqbalance`
- `samba4-server` (si usas NAS)
- `tailscale`
- `luci`, `luci-ssl`

---

## 12. VPN POLICY ROUTING (reglas UCI)

```
novpn_to_main:      mark 0x8000/0xf000, priority 6000, lookup main
vpn_leak_block:     mark 0x0/0xf000, priority 9910, action blackhole (inverted)
vpn_block_lan_leak: in lan, priority 9920, action blackhole
vpn_to_main:        mark 0x0/0xf000, priority 9000, lookup main (inverted)
main_static_net:    suppress_prefixlength 0, priority 800, lookup 9910
```

---

## 13. NOTAS PARA LA MIGRACION

1. **WireGuard**: GL.iNet usa `proto wgserver` - en vanilla es `proto wireguard`. Recrea la config.
2. **DNS marks**: El sistema de marcado DNS (0x8000/0xf000) es especifico de GL.iNet con `kmod-gl-sdk4-dns-mark`. Necesitaras replicar esto o usar otro enfoque.
3. **AdGuard Home**: Instalar binario manualmente, escucha en :3053, dnsmasq forwarding a 127.0.0.1#3053.
4. **Scripts custom**: Copiar `/etc/script/` y `/usr/bin/monitor/` - revisar dependencias de herramientas GL.iNet.
5. **Syslog remoto**: Configurar logd para enviar a Papertrail.
6. **VLAN 881 WAN**: Verificar que OpenWrt vanilla soporte esta config (eth1.881).
7. **QoSmate**: Funciona en vanilla OpenWrt - instalar normalmente.
8. **802.11r**: Requiere `wpad-openssl` o `wpad-wolfssl` (no `wpad-basic`).
