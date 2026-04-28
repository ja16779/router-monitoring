#!/bin/sh
# post_upgrade25.sh — Setup post-upgrade en OpenWrt 25.12 nativo (apk)
# Correr MANUALMENTE desde USB después de que el router arranque con OpenWrt 25.12
#
# Uso: sh /mnt/<usb>/post_upgrade25.sh
#
# El script detecta el USB automáticamente, instala paquetes con apk
# y crea un backup inicial.

LOGTAG="post-upgrade25"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"
LOG="/tmp/post_upgrade25.log"

# Paquetes GL.iNet-específicos que NO existen en OpenWrt nativo
GLINET_EXCLUDE="gl-sdk4 gl-sdk4-alsa gl-sdk4-cellular gl-sdk4-glinet gl-sdk4-iot
    gl-sdk4-led gl-sdk4-mcu gl-sdk4-modem gl-sdk4-ovpn gl-sdk4-tailscale
    gl-sdk4-ui gl-base-files gl-api-daemon glinet kmod-gl-sdk4-kmwan
    internet-detector internet-detector-mod-telegram
    bark-router-client luci-app-internet-detector luci-app-netspeedtest
    luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn luci-i18n-package-manager-zh-cn
    mptcpd librespeed-go syslog-ng luci-app-log-viewer
    luci-app-package-manager rpcd-mod-luci rpcd-mod-rrdns
    luci-lib-uqr luci-lua-runtime luci-compat
    confuse ell ivykis0 libdbi libfido2-1"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; logger -t "$LOGTAG" "$*"; }

send_telegram() {
    curl -skim 15 \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

is_excluded() {
    local pkg="$1"
    for ex in $GLINET_EXCLUDE; do
        [ "$pkg" = "$ex" ] && return 0
    done
    case "$pkg" in kmod-*|nginx-*|libluci*) return 0 ;; esac
    return 1
}

# ── 1. Detectar y montar USB ──────────────────────────────────────────────────
log "=== post_upgrade25.sh — $(date) ==="
log "OpenWrt: $(grep DISTRIB_RELEASE /etc/openwrt_release 2>/dev/null | cut -d= -f2 | tr -d \"'\")"

USB=""
for candidate in /mnt/sda1 /mnt/sdb1 /mnt/usb1_part1 /mnt/sda /mnt/usb; do
    if mountpoint -q "$candidate" 2>/dev/null; then
        USB="$candidate"
        log "USB encontrado en: $USB"
        break
    fi
done

if [ -z "$USB" ]; then
    log "USB no montado. Intentando montar..."
    mkdir -p /mnt/usb
    for dev in /dev/sda1 /dev/sdb1 /dev/sdc1; do
        if [ -b "$dev" ]; then
            mount "$dev" /mnt/usb 2>/dev/null && USB="/mnt/usb" && log "Montado $dev en /mnt/usb" && break
        fi
    done
fi

[ -z "$USB" ] && log "ADVERTENCIA: USB no encontrado, continuando sin él"

PKG_LIST="${USB}/my_installed_packages.txt"

# ── 2. Actualizar índice apk ──────────────────────────────────────────────────
log ">>> apk update..."
if ! apk update >> "$LOG" 2>&1; then
    log "ERROR: apk update falló. Sin conexión a internet?"
    send_telegram "<b>❌ post_upgrade25 fallido — GL-MT6000</b><pre>apk update falló</pre>"
    exit 1
fi
log "apk update OK"

# ── 3. Instalar paquetes esenciales base ──────────────────────────────────────
log ">>> Instalando paquetes base..."
BASE_PKGS="curl bash nano htop jq tcpdump mwan3 luci luci-app-mwan3
    luci-app-firewall luci-app-commands luci-mod-admin-full
    mdns-repeater usteer irqbalance zram-swap
    logrotate bmon nload fping drill whois sshpass
    netperf speedtest-netperf tc-full python3-light tar xz-utils btop"

for pkg in $BASE_PKGS; do
    if apk info "$pkg" >/dev/null 2>&1; then
        log "  ya instalado: $pkg"
    else
        log -n "  instalando $pkg..."
        if apk add "$pkg" >> "$LOG" 2>&1; then
            log " OK"
        else
            log " FALLO (no disponible en OpenWrt nativo)"
        fi
    fi
done

# ── 4. Instalar paquetes del backup (lista guardada en USB) ───────────────────
if [ -f "$PKG_LIST" ]; then
    log ">>> Instalando paquetes del backup desde: $PKG_LIST"
    OK=0; FAIL=0; SKIP=0
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        if is_excluded "$pkg"; then
            log "  excluido (GL.iNet): $pkg"
            SKIP=$((SKIP + 1))
            continue
        fi
        if apk info "$pkg" >/dev/null 2>&1; then
            SKIP=$((SKIP + 1))
            continue
        fi
        if apk add "$pkg" >> "$LOG" 2>&1; then
            log "  +$pkg"
            OK=$((OK + 1))
        else
            log "  FALLO: $pkg"
            FAIL=$((FAIL + 1))
        fi
    done < "$PKG_LIST"
    log "Paquetes del backup: +$OK instalados, $FAIL fallidos, $SKIP omitidos"
else
    log "ADVERTENCIA: $PKG_LIST no encontrado, solo paquetes base instalados"
fi

# ── 5. Copiar scripts al router ───────────────────────────────────────────────
if [ -n "$USB" ] && [ -d "${USB}/script" ]; then
    log ">>> Copiando /etc/script desde USB..."
    mkdir -p /etc/script
    cp -r "${USB}/script/." /etc/script/
    chmod +x /etc/script/*.sh 2>/dev/null
    log "Scripts copiados"
fi

# ── 6. Backup inicial del nuevo sistema ──────────────────────────────────────
if [ -n "$USB" ]; then
    log ">>> Creando backup inicial en USB..."
    OWRT=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d= -f2 | tr -d "'")
    BKPFILE="/tmp/backup-GL-MT6000-${OWRT}-$(date +%F).tar.gz"
    sysupgrade -b "$BKPFILE" 2>/dev/null
    if [ -f "$BKPFILE" ]; then
        cp "$BKPFILE" "${USB}/"
        log "Backup guardado: ${USB}/${BKPFILE##*/}"
    fi
fi

# ── 7. Notificar ─────────────────────────────────────────────────────────────
OWRT=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d= -f2 | tr -d "'")
FAIL_LIST=$(grep "FALLO:" "$LOG" | sed 's/.*FALLO: //' | tr '\n' ' ')

send_telegram "<b>✅ GL-MT6000 — OpenWrt 25.12 listo</b>
<pre>
Version:   $OWRT
USB:       ${USB:-no montado}
Log:       $LOG
</pre>${FAIL_LIST:+<b>Fallidos:</b> <pre>$FAIL_LIST</pre>}"

log "=== post_upgrade25.sh completado ==="
echo ""
echo "Log completo: $LOG"
echo ""
echo "Próximos pasos manuales:"
echo "  1. Configurar red en LuCI (192.168.1.1) o via uci"
echo "  2. Configurar AdGuardHome si se necesita"
echo "  3. Revisar config de mwan3, mdns-repeater, usteer"
