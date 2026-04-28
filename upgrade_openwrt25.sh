#!/bin/sh
# upgrade_openwrt25.sh — Actualiza Flint 2 a OpenWrt 25.12.0-rc5 nativo
# Corre en GL.iNet 24.10 antes del flash
#
# IMPORTANTE: sysupgrade -n borra TODA la config (necesario: GL.iNet → nativo)
# Después del reboot el router responde en 192.168.1.1 (default OpenWrt)
#
# Uso: sh /etc/script/upgrade_openwrt25.sh

LOGTAG="upgrade25"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"

BASE_URL="https://downloads.openwrt.org/releases/25.12.0-rc5/targets/mediatek/filogic"
FIRMWARE="openwrt-25.12.0-rc5-mediatek-filogic-glinet_gl-mt6000-squashfs-sysupgrade.bin"
EXPECTED_SHA256="10f91eb6ad233eb4bfd9aba5cdc59082b3630b1ec02bdc1cffbea83033ce3239"

TMPFW="/tmp/${FIRMWARE}"
USB="/tmp/mountd/disk2_part1"
POST_SCRIPT="/etc/script/post_upgrade25.sh"

log() { echo "[$(date '+%H:%M:%S')] $*"; logger -t "$LOGTAG" "$*"; }

send_telegram() {
    curl -skim 10 \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

# ── 1. Guardar lista de paquetes actualizada ──────────────────────────────────
log ">>> Guardando lista de paquetes..."
/etc/script/pkg_manager.sh save
log "OK"

# ── 2. Backup al USB ──────────────────────────────────────────────────────────
log ">>> Creando backup en USB..."
/etc/script/backup.sh
log "Backup completado"

# ── 3. Copiar post_upgrade25.sh al USB (sobrevive al flash) ──────────────────
if [ -d "$USB" ]; then
    cp "$POST_SCRIPT" "${USB}/post_upgrade25.sh"
    cp /etc/config/my_installed_packages "${USB}/my_installed_packages.txt" 2>/dev/null
    log "post_upgrade25.sh copiado a USB"
else
    log "ADVERTENCIA: USB no encontrado en $USB, continúa de todas formas"
fi

# ── 4. Descargar firmware ─────────────────────────────────────────────────────
log ">>> Descargando OpenWrt 25.12.0-rc5 para GL-MT6000..."
log "    URL: ${BASE_URL}/${FIRMWARE}"
log "    Destino: $TMPFW"

if ! curl -o "$TMPFW" --progress-bar --max-time 300 "${BASE_URL}/${FIRMWARE}" 2>&1; then
    log "ERROR: Descarga fallida"
    send_telegram "<b>❌ Upgrade fallido — GL-MT6000</b><pre>Error: descarga de firmware</pre>"
    exit 1
fi
log "Descarga completada: $(ls -lh "$TMPFW" | awk '{print $5}')"

# ── 5. Verificar SHA256 ───────────────────────────────────────────────────────
log ">>> Verificando SHA256..."
ACTUAL_SHA256=$(sha256sum "$TMPFW" | awk '{print $1}')
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
    log "ERROR: Checksum no coincide!"
    log "  Esperado: $EXPECTED_SHA256"
    log "  Obtenido: $ACTUAL_SHA256"
    rm -f "$TMPFW"
    send_telegram "<b>❌ Upgrade fallido — GL-MT6000</b><pre>Error: checksum inválido</pre>"
    exit 1
fi
log "SHA256 OK: $ACTUAL_SHA256"

# ── 6. Notificar y flashear ───────────────────────────────────────────────────
send_telegram "<b>🔄 Upgrade iniciado — GL-MT6000</b>
<pre>
Firmware:  OpenWrt 25.12.0-rc5 nativo
SHA256:    OK
Nota:      Config se BORRA (-n)
Acceso:    192.168.1.1 tras reboot
</pre>"

log ">>> Flasheando... el router se reiniciará solo."
log "    Tras el reboot: http://192.168.1.1 (OpenWrt default)"
log "    Correr desde USB: sh /mnt/<usb>/post_upgrade25.sh"

sysupgrade -n "$TMPFW"
