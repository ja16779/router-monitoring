#!/bin/sh
# post_openwrt25.sh — Restaura GL-MT6000 tras migrar a OpenWrt 25 nativo (apk)
# Corre MANUALMENTE desde USB despues del primer boot en OpenWrt 25.12
#
# Uso: sh /mnt/<usb>/post_openwrt25.sh
#
# Que hace:
#   1. Instala paquetes con apk
#   2. Configura red: VLAN 8 (IoT), VLAN 10 (LAN), WAN PPPoE vlan 881
#   3. Configura DHCP, firewall, wireless
#   4. Configura mwan3, mdns-repeater, usteer
#   5. Restaura SSH key para sync con Beryl
#   6. Restaura scripts y crontab desde USB
#   7. Configura hotplug sync leases a Beryl

LOGTAG="post-openwrt25"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"
LOG="/tmp/post_openwrt25.log"

# Paquetes GL.iNet que NO existen en OpenWrt nativo — excluir
GLINET_EXCLUDE="gl-sdk4 gl-base-files gl-api-daemon glinet bark-router-client
    internet-detector luci-app-internet-detector luci-app-package-manager
    mptcpd librespeed-go syslog-ng luci-app-log-viewer confuse ell ivykis0
    libdbi libfido2-1 gl-sdk4-ui rpcd-mod-luci luci-compat luci-lua-runtime
    dnscrypt-proxy2 getdns"

log()    { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; logger -t "$LOGTAG" "$*"; }
log_ok() { log "  [OK] $*"; }
log_err(){ log "  [!!] $*"; }

send_telegram() {
    curl -skim 15 --data parse_mode="HTML" --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

is_excluded() {
    local pkg="$1"
    for ex in $GLINET_EXCLUDE; do [ "$pkg" = "$ex" ] && return 0; done
    case "$pkg" in
        gl-sdk4-*|gl-oui-*|gl-line-*|aw-s2s|bark-*|luci-i18n-*-zh-cn) return 0 ;;
    esac
    return 1
}

log "=== post_openwrt25.sh === $(date)"
log "OpenWrt: $(grep DISTRIB_RELEASE /etc/openwrt_release 2>/dev/null | cut -d= -f2 | tr -d "'")"

# ── Detectar USB ──────────────────────────────────────────────────────────────
USB=""
for p in /mnt/sda1 /mnt/sdb1 /mnt/usb1_part1 /mnt/sda /mnt/usb; do
    mountpoint -q "$p" 2>/dev/null && USB="$p" && break
done
if [ -z "$USB" ]; then
    log "USB no montado, buscando dispositivo..."
    mkdir -p /mnt/usb
    for dev in /dev/sda1 /dev/sdb1 /dev/sdc1; do
        [ -b "$dev" ] && mount "$dev" /mnt/usb 2>/dev/null && USB="/mnt/usb" && break
    done
fi
[ -n "$USB" ] && log "USB: $USB" || log "ADVERTENCIA: USB no encontrado, continuando sin el"

PRE_DIR="$(ls -td ${USB}/pre-upgrade-* 2>/dev/null | head -1)"
PKG_LIST="${USB}/my_installed_packages.txt"
log "Backup pre-upgrade: ${PRE_DIR:-no encontrado}"

# ────────────────────────────────────────────────────────────────────────────
# 1. PAQUETES
# ────────────────────────────────────────────────────────────────────────────
log ">>> 1/8 Instalando paquetes..."
apk update >> "$LOG" 2>&1 || { log_err "apk update fallo"; exit 1; }

BASE_PKGS="curl bash nano htop jq tcpdump mwan3 luci luci-app-mwan3
    luci-app-firewall luci-app-commands
    mdns-repeater usteer
    zram-swap logrotate
    bmon nload fping drill
    netperf speedtest-netperf
    btop python3-light tar xz
    kmod-fs-ext4 kmod-fs-vfat kmod-fs-exfat e2fsprogs
    block-mount"

for pkg in $BASE_PKGS; do
    if apk info "$pkg" >/dev/null 2>&1; then
        log "  ya instalado: $pkg"
    else
        apk add "$pkg" >> "$LOG" 2>&1 && log_ok "$pkg" || log "  SKIP (no disponible): $pkg"
    fi
done

if [ -f "$PKG_LIST" ]; then
    log "  Instalando lista del backup: $PKG_LIST"
    OK=0; FAIL=0; SKIP=0
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        is_excluded "$pkg" && { SKIP=$((SKIP+1)); continue; }
        apk info "$pkg" >/dev/null 2>&1 && { SKIP=$((SKIP+1)); continue; }
        apk add "$pkg" >> "$LOG" 2>&1 && { OK=$((OK+1)); log_ok "$pkg"; } || FAIL=$((FAIL+1))
    done < "$PKG_LIST"
    log "  Paquetes del backup: +$OK OK, $FAIL fallidos, $SKIP omitidos"
fi

# ────────────────────────────────────────────────────────────────────────────
# 2. RED — VLAN 8 (IoT) + VLAN 10 (LAN) + WAN PPPoE
# ────────────────────────────────────────────────────────────────────────────
log ">>> 2/8 Configurando red..."

# Bridge base
uci batch << 'UCI_NETWORK'
set network.@device[0].name='br-lan'
set network.@device[0].type='bridge'
set network.@device[0].ports='lan2 lan3 lan4 lan5'
set network.@device[0].bridge_empty='1'
set network.@device[0].stp='0'
UCI_NETWORK

# VLAN 8 — IoT: solo lan5 trunk al Beryl + wireless
uci -q delete network.vlan8
uci set network.vlan8=bridge-vlan
uci set network.vlan8.device='br-lan'
uci set network.vlan8.vlan='8'
uci set network.vlan8.ports='lan5:t'

# VLAN 10 — LAN principal
uci -q delete network.vlan10
uci set network.vlan10=bridge-vlan
uci set network.vlan10.device='br-lan'
uci set network.vlan10.vlan='10'
uci set network.vlan10.ports='lan2 lan3 lan4 lan5:t'

# Interface IoT
uci set network.IOT=interface
uci set network.IOT.device='br-lan.8'
uci set network.IOT.proto='static'
uci set network.IOT.ipaddr='192.168.8.1'
uci set network.IOT.netmask='255.255.255.0'
uci set network.IOT.dns='127.0.0.1'

# Interface LAN
uci set network.lan.device='br-lan.10'
uci set network.lan.proto='static'
uci set network.lan.ipaddr='192.168.10.1'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.dns='127.0.0.1'

# WAN PPPoE VLAN 881
uci set network.wan.device='eth1.881'
uci set network.wan.proto='pppoe'
uci set network.wan.username='44F436LZTEG245294E1@prodigyweb.com.mx'
uci set network.wan.ipv6='0'
uci set network.wan.mtu='1492'
uci set network.wan.keepalive='10 6'
uci set network.wan.multipath='on'
uci set network.wan6.disabled='1'

uci commit network
log_ok "Red configurada (VLAN 8/10, WAN PPPoE vlan 881)"

# ────────────────────────────────────────────────────────────────────────────
# 3. DHCP
# ────────────────────────────────────────────────────────────────────────────
log ">>> 3/8 Configurando DHCP..."

uci set dhcp.@dnsmasq[0].authoritative='1'
uci set dhcp.@dnsmasq[0].rebind_protection='1'
uci set dhcp.@dnsmasq[0].local='/lan/'
uci set dhcp.@dnsmasq[0].domain='lan'
uci set dhcp.@dnsmasq[0].readethers='1'
uci set dhcp.@dnsmasq[0].leasefile='/tmp/dhcp.leases'
uci set dhcp.@dnsmasq[0].filter_aaaa='1'
uci set dhcp.@dnsmasq[0].sequential_ip='1'
uci set dhcp.@dnsmasq[0].dhcpleasemax='300'
uci set dhcp.@dnsmasq[0].noresolv='1'
uci set dhcp.@dnsmasq[0].server='127.0.0.1#3053'

uci set dhcp.lan.interface='lan'
uci set dhcp.lan.start='100'
uci set dhcp.lan.limit='150'
uci set dhcp.lan.leasetime='72h'
uci set dhcp.lan.dhcp_option='42,192.168.10.1'

uci set dhcp.IOT=dhcp
uci set dhcp.IOT.interface='IOT'
uci set dhcp.IOT.start='100'
uci set dhcp.IOT.limit='150'
uci set dhcp.IOT.leasetime='72h'
uci set dhcp.IOT.dhcp_option='42,192.168.8.1'

uci set dhcp.wan.ignore='1'
uci commit dhcp
log_ok "DHCP configurado (LAN 10.100-249, IoT 8.100-249)"

# ────────────────────────────────────────────────────────────────────────────
# 4. FIREWALL
# ────────────────────────────────────────────────────────────────────────────
log ">>> 4/8 Configurando firewall..."

uci set firewall.@zone[0].name='lan'
uci set firewall.@zone[0].input='ACCEPT'
uci set firewall.@zone[0].output='ACCEPT'
uci set firewall.@zone[0].forward='ACCEPT'
uci set firewall.@zone[0].network='lan IOT'

uci set firewall.@zone[1].name='wan'
uci set firewall.@zone[1].input='DROP'
uci set firewall.@zone[1].output='ACCEPT'
uci set firewall.@zone[1].forward='REJECT'
uci set firewall.@zone[1].masq='1'
uci set firewall.@zone[1].mtu_fix='1'
uci set firewall.@zone[1].network='wan wan6'

uci commit firewall
log_ok "Firewall configurado"

# ────────────────────────────────────────────────────────────────────────────
# 5. WIRELESS
# ────────────────────────────────────────────────────────────────────────────
log ">>> 5/8 Configurando wireless..."
WIFI_KEY="Axtel200"

uci set wireless.radio0.band='2g'
uci set wireless.radio0.channel='6'
uci set wireless.radio0.htmode='HE20'
uci set wireless.radio0.country='MX'
uci set wireless.radio0.txpower='20'
uci set wireless.radio0.cell_density='1'
uci -q delete wireless.radio0.random_bssid

uci set wireless.radio1.band='5g'
uci set wireless.radio1.channel='44'
uci set wireless.radio1.htmode='HE80'
uci set wireless.radio1.country='MX'
uci set wireless.radio1.cell_density='1'
uci -q delete wireless.radio1.random_bssid

# AXTEL XTREMO 5G — VLAN 10 (red principal)
uci set wireless.wifi5g=wifi-iface
uci set wireless.wifi5g.device='radio1'
uci set wireless.wifi5g.network='lan'
uci set wireless.wifi5g.mode='ap'
uci set wireless.wifi5g.ssid='AXTEL XTREMO'
uci set wireless.wifi5g.encryption='psk2'
uci set wireless.wifi5g.key="$WIFI_KEY"
uci set wireless.wifi5g.ieee80211r='1'
uci set wireless.wifi5g.mobility_domain='123F'
uci set wireless.wifi5g.ft_over_ds='1'
uci set wireless.wifi5g.ft_psk_generate_local='1'
uci set wireless.wifi5g.ieee80211k='1'

# AXTEL XTREMO 2.4G — VLAN 10
uci set wireless.wifinet4=wifi-iface
uci set wireless.wifinet4.device='radio0'
uci set wireless.wifinet4.network='lan'
uci set wireless.wifinet4.mode='ap'
uci set wireless.wifinet4.ssid='AXTEL XTREMO'
uci set wireless.wifinet4.encryption='psk-mixed'
uci set wireless.wifinet4.key="$WIFI_KEY"
uci set wireless.wifinet4.ieee80211k='1'

# IOT 2.4G — VLAN 8
uci set wireless.wifinet3=wifi-iface
uci set wireless.wifinet3.device='radio0'
uci set wireless.wifinet3.network='IOT'
uci set wireless.wifinet3.mode='ap'
uci set wireless.wifinet3.ssid='IOT'
uci set wireless.wifinet3.encryption='psk-mixed'
uci set wireless.wifinet3.key="$WIFI_KEY"

# Mega 2.4G — VLAN 8
uci set wireless.guest2g=wifi-iface
uci set wireless.guest2g.device='radio0'
uci set wireless.guest2g.network='IOT'
uci set wireless.guest2g.mode='ap'
uci set wireless.guest2g.ssid='Mega_2.4G_A2DF'
uci set wireless.guest2g.encryption='psk-mixed'
uci set wireless.guest2g.key="$WIFI_KEY"

# Mega 5G — VLAN 8
uci set wireless.guest5g=wifi-iface
uci set wireless.guest5g.device='radio1'
uci set wireless.guest5g.network='IOT'
uci set wireless.guest5g.mode='ap'
uci set wireless.guest5g.ssid='Mega_5G_A2DF'
uci set wireless.guest5g.encryption='psk2'
uci set wireless.guest5g.key="$WIFI_KEY"

uci commit wireless
log_ok "Wireless configurado (5 SSIDs)"

# ────────────────────────────────────────────────────────────────────────────
# 6. mwan3 + mdns-repeater + usteer
# ────────────────────────────────────────────────────────────────────────────
log ">>> 6/8 Configurando mwan3, mdns-repeater, usteer..."

# mwan3 — wan_only policy
uci set mwan3.wan=interface
uci set mwan3.wan.enabled='1'
uci set mwan3.wan.count='2'
uci set mwan3.wan.timeout='2'
uci set mwan3.wan.interval='5'
uci set mwan3.wan.down='3'
uci set mwan3.wan.up='8'
uci -q delete mwan3.wan.track_ip
uci add_list mwan3.wan.track_ip='8.8.8.8'
uci add_list mwan3.wan.track_ip='8.8.4.4'
uci set mwan3.wan_m1_w3=member
uci set mwan3.wan_m1_w3.interface='wan'
uci set mwan3.wan_m1_w3.metric='1'
uci set mwan3.wan_m1_w3.weight='3'
uci set mwan3.wan_only=policy
uci set mwan3.wan_only.use_member='wan_m1_w3'
uci set mwan3.default_rule=rule
uci set mwan3.default_rule.use_policy='wan_only'
uci set mwan3.default_rule.dest_ip='0.0.0.0/0'
uci set mwan3.default_rule.family='ipv4'
uci commit mwan3

# mdns-repeater — IoT <-> LAN para impresoras/Chromecast
UCI_MDNS=$(uci -q get mdns_repeater.@mdns_repeater[0] 2>/dev/null)
if [ -z "$UCI_MDNS" ]; then
    uci add mdns_repeater mdns_repeater
fi
uci set mdns_repeater.@mdns_repeater[0].interface='br-lan.8 br-lan.10'
uci commit mdns_repeater

# usteer — roaming en red LAN
uci set usteer.config=usteer
uci set usteer.config.syslog='1'
uci set usteer.config.local_mode='0'
uci set usteer.config.ipv6='0'
uci set usteer.config.network='lan'
uci set usteer.config.debug_level='0'
uci commit usteer

log_ok "mwan3, mdns-repeater, usteer configurados"

# ────────────────────────────────────────────────────────────────────────────
# 7. SSH KEY + SCRIPTS + CRONTAB + HOTPLUG
# ────────────────────────────────────────────────────────────────────────────
log ">>> 7/8 Restaurando SSH, scripts y crontab..."

mkdir -p /root/.ssh
chmod 700 /root/.ssh

SSH_BACKUP="${PRE_DIR}/ssh/id_dropbear"
if [ -f "$SSH_BACKUP" ]; then
    cp "$SSH_BACKUP" /root/.ssh/id_dropbear
    chmod 600 /root/.ssh/id_dropbear
    log_ok "SSH key restaurada desde backup"
else
    dropbearkey -t ed25519 -f /root/.ssh/id_dropbear 2>/dev/null
    PUBKEY=$(dropbearkey -y -f /root/.ssh/id_dropbear 2>/dev/null | grep ssh-ed25519)
    log "Nueva SSH key generada"
    log "ATENCION: instala en Beryl /etc/dropbear/authorized_keys:"
    log "  $PUBKEY"
fi

# Restaurar scripts
mkdir -p /etc/script
if [ -d "${PRE_DIR}/script" ]; then
    cp -r "${PRE_DIR}/script/." /etc/script/
    chmod +x /etc/script/*.sh 2>/dev/null
    log_ok "Scripts restaurados: $(ls /etc/script/*.sh 2>/dev/null | wc -l) archivos"
elif [ -d "${USB}/script" ]; then
    cp -r "${USB}/script/." /etc/script/
    chmod +x /etc/script/*.sh 2>/dev/null
    log_ok "Scripts restaurados desde raiz USB"
else
    log "ADVERTENCIA: No se encontraron scripts en backup"
fi

# Crontab
if [ -f "${PRE_DIR}/crontab.txt" ]; then
    cp "${PRE_DIR}/crontab.txt" /etc/crontabs/root
    log_ok "Crontab restaurado desde backup"
elif [ -f "${USB}/crontab.txt" ]; then
    cp "${USB}/crontab.txt" /etc/crontabs/root
    log_ok "Crontab restaurado desde raiz USB"
fi

# Hotplug: sync dhcp.leases al Beryl en cada evento DHCP
mkdir -p /etc/hotplug.d/dhcp
cat > /etc/hotplug.d/dhcp/50-sync-beryl << 'HOTPLUG'
#!/bin/sh
# Sincroniza /tmp/dhcp.leases al Beryl AX tras cada evento DHCP
[ -n "$IPADDR" ] || exit 0
scp -i /root/.ssh/id_dropbear \
    -o StrictHostKeyChecking=no \
    /tmp/dhcp.leases \
    root@192.168.10.2:/tmp/dhcp.leases 2>/dev/null
logger -t sync-beryl-leases "sync $ACTION $MACADDR $IPADDR ${HOSTNAME:-?}"
HOTPLUG
chmod +x /etc/hotplug.d/dhcp/50-sync-beryl
log_ok "Hotplug sync-beryl instalado"

# sysupgrade.conf
cat > /etc/sysupgrade.conf << 'SYSUP'
/etc/script/
/etc/crontabs/root
/etc/hotplug.d/dhcp/50-sync-beryl
/root/.ssh/id_dropbear
SYSUP
log_ok "sysupgrade.conf configurado"

# ────────────────────────────────────────────────────────────────────────────
# 8. HABILITAR SERVICIOS
# ────────────────────────────────────────────────────────────────────────────
log ">>> 8/8 Habilitando servicios..."

for svc in mwan3 mdns-repeater usteer cron; do
    /etc/init.d/$svc enable 2>/dev/null && /etc/init.d/$svc start 2>/dev/null
    log "  $svc: enabled+started"
done

/etc/init.d/network restart 2>/dev/null
/etc/init.d/dnsmasq restart 2>/dev/null
/etc/init.d/firewall restart 2>/dev/null
sleep 3
wifi reload 2>/dev/null

# ── Resumen ───────────────────────────────────────────────────────────────────
OWRT_NEW=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d= -f2 | tr -d "'")
FAIL_LIST=$(grep "SKIP (no disponible)" "$LOG" | sed 's/.*SKIP (no disponible): //' | tr '\n' ' ')

send_telegram "<b>GL-MT6000 — OpenWrt 25 configurado</b>
<pre>
Version:  $OWRT_NEW
USB:      ${USB:-no montado}
</pre>
Configurado:
- Red: VLAN 8 (IoT 8.1), VLAN 10 (LAN 10.1)
- WAN: PPPoE eth1.881
- WiFi: 5 SSIDs (AXTEL / IOT / Mega)
- mwan3 + mdns-repeater + usteer
- SSH key Beryl sync restaurada
- Scripts + crontab restaurados
${FAIL_LIST:+Paquetes no disponibles: $FAIL_LIST}"

log "=== post_openwrt25.sh completado ==="
echo ""
echo "Log: $LOG"
echo ""
echo "Verifica:"
echo "  ip addr show br-lan.8 br-lan.10"
echo "  mwan3 status"
echo "  uci show wireless | grep ssid"
echo "  cat /etc/crontabs/root"
