#!/bin/sh
# pre_openwrt25.sh — Backup completo antes de migrar a OpenWrt 25 nativo
# Corre en GL.iNet OpenWrt 24.10 con opkg
# Guarda todo en el USB y notifica por Telegram.
# Uso: sh /etc/script/pre_openwrt25.sh

LOGTAG="pre-openwrt25"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"
LOG="/tmp/pre_openwrt25.log"
USB="/tmp/mountd/disk2_part1"
OWRT=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d= -f2 | tr -d "'")
DATE=$(date +%F)
HOSTNAME=$(uname -n)

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; logger -t "$LOGTAG" "$*"; }

send_telegram() {
    curl -skim 10 --data parse_mode="HTML" --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

log "=== pre_openwrt25.sh === $(date)"
log "Router: $HOSTNAME | OpenWrt: $OWRT"

# ── Verificar USB ─────────────────────────────────────────────────────────────
# df muestra el dispositivo (/dev/sdX) si esta montado como filesystem real
if ! df "$USB" 2>/dev/null | grep -q "^/dev/"; then
    log "ERROR: USB no montado en $USB"
    log "Verifica: df -h | grep sda"
    exit 1
fi

DEST="${USB}/pre-upgrade-${DATE}"
mkdir -p "$DEST"
log "Destino: $DEST"

# ── 1. Lista de paquetes (opkg) ───────────────────────────────────────────────
log ">>> 1/7 Guardando lista de paquetes (opkg)..."
opkg list-installed > "${DEST}/opkg-list-installed.txt"
opkg list-installed | awk '{print $1}' > "${DEST}/opkg-pkgs-only.txt"
cp /etc/config/my_installed_packages "${DEST}/my_installed_packages.txt" 2>/dev/null
log "  $(wc -l < "${DEST}/opkg-list-installed.txt") paquetes guardados"

# ── 2. UCI export completo ────────────────────────────────────────────────────
log ">>> 2/7 Exportando config UCI completa..."
uci export > "${DEST}/uci-export-full.txt"
log "  UCI export: $(wc -l < "${DEST}/uci-export-full.txt") lineas"

# ── 3. Backup sysupgrade ──────────────────────────────────────────────────────
log ">>> 3/7 Creando backup sysupgrade..."
BKPFILE="/tmp/backup-${HOSTNAME}-${OWRT}-${DATE}.tar.gz"
sysupgrade -b "$BKPFILE"
if [ -f "$BKPFILE" ]; then
    cp "$BKPFILE" "$DEST/"
    log "  Backup: $(ls -lh "$BKPFILE" | awk '{print $5}')"
else
    log "  ADVERTENCIA: sysupgrade -b fallo"
fi

# ── 4. Copiar scripts y crontab ───────────────────────────────────────────────
log ">>> 4/7 Copiando scripts y crontab..."
cp -r /etc/script/ "${DEST}/script/"
cp /etc/crontabs/root "${DEST}/crontab.txt"
cp -r /etc/hotplug.d/ "${DEST}/hotplug.d/" 2>/dev/null
log "  Scripts: $(ls "${DEST}/script/" | wc -l) archivos"

# ── 5. Copiar SSH keys ────────────────────────────────────────────────────────
log ">>> 5/7 Copiando SSH keys..."
mkdir -p "${DEST}/ssh"
cp /root/.ssh/id_dropbear "${DEST}/ssh/" 2>/dev/null
cp /root/.ssh/known_hosts "${DEST}/ssh/" 2>/dev/null
dropbearkey -y -f /root/.ssh/id_dropbear 2>/dev/null | grep ssh-ed25519 > "${DEST}/ssh/id_dropbear.pub"
log "  Llave SSH guardada"

# ── 6. Config /etc/config completa ───────────────────────────────────────────
log ">>> 6/7 Copiando /etc/config completa..."
cp -r /etc/config/ "${DEST}/etc-config/"
log "  Config: $(ls "${DEST}/etc-config/" | wc -l) archivos"

# ── 7. Info del sistema ───────────────────────────────────────────────────────
log ">>> 7/7 Guardando info del sistema..."
{
    echo "=== OpenWrt release ==="
    cat /etc/openwrt_release
    echo "=== uname ==="
    uname -a
    echo "=== IP ==="
    ip addr show br-lan.8 br-lan.10 pppoe-wan 2>/dev/null
    echo "=== WAN ==="
    ip route
    echo "=== mwan3 ==="
    mwan3 status 2>/dev/null
} > "${DEST}/sysinfo.txt"

# ── Copiar post script al raiz del USB ───────────────────────────────────────
cp /etc/script/post_openwrt25.sh "${USB}/post_openwrt25.sh" 2>/dev/null \
    && log "post_openwrt25.sh copiado al raiz del USB" \
    || log "ADVERTENCIA: post_openwrt25.sh no encontrado en /etc/script/"

cp "${DEST}/opkg-pkgs-only.txt" "${USB}/my_installed_packages.txt"

# ── Resumen ───────────────────────────────────────────────────────────────────
TOTAL_SIZE=$(du -sh "$DEST" | cut -f1)
log "=== Backup completo en: $DEST (${TOTAL_SIZE}) ==="

send_telegram "<b>GL-MT6000 — pre_openwrt25 listo</b>
<pre>
Router:   $HOSTNAME
OpenWrt:  $OWRT
Destino:  $DEST
Tamanio:  $TOTAL_SIZE
Fecha:    $DATE
</pre>
Proximo: sh /etc/script/upgrade_openwrt25.sh"

echo ""
echo "Backup guardado en: $DEST"
echo "Log: $LOG"
echo ""
echo "Proximos pasos:"
echo "  1. Verifica el backup: ls $DEST"
echo "  2. Flashea: sh /etc/script/upgrade_openwrt25.sh"
echo "  3. Post-upgrade: sh ${USB}/post_openwrt25.sh"
