#!/bin/sh

# Telegram Bot Credentials
TOKEN="REDACTED_BOT_TOKEN"
CHAT_ID="716542586"

# Detectar destino USB segun firmware
if [ -d "/mnt/sda1" ]; then
    BACKUP_DEST="/mnt/sda1"
else
    BACKUP_DEST="/tmp/mountd/disk2_part1"
fi

send_to_telegram() {
    # Log the message locally
    logger -p local0.info -t backup-new "$1"

    if [ -n "$TOKEN" ] && [ -n "$CHAT_ID" ]; then
        curl --silent --show-error --max-time 10 \
            --data "disable_notification=false" \
            --data "parse_mode=MarkdownV2" \
            --data "chat_id=$CHAT_ID" \
            --data-urlencode "text=$1" \
            "https://api.telegram.org/bot${TOKEN}/sendMessage" > /dev/null
    else
        logger -p local0.info -t backup-new "Error: Telegram token or chat ID is empty"
    fi
}

# Obtener versiones
OPENWRT_VERSION=$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d'=' -f2 | tr -d "'")
GLINET_VERSION="$(cat /etc/glversion 2>/dev/null)"

# Etiqueta de version para nombre de archivo
if [ -n "$GLINET_VERSION" ]; then
    FW_LABEL="${OPENWRT_VERSION}-gl${GLINET_VERSION}"
else
    FW_LABEL="${OPENWRT_VERSION}"
fi

/etc/script/pkg_manager.sh save

# Ensure file permissions
umask go=

# Create Backup
BACKUP_FILE="/tmp/backup-${HOSTNAME}-${FW_LABEL}-$(date +%F).tar.gz"
sysupgrade -b "$BACKUP_FILE"

# Confirm Backup Creation
if [ ! -f "$BACKUP_FILE" ]; then
    logger -p local0.info -t backup-new "Error: Backup file not created"
    exit 1
fi

# Copy Backup to Target Locations
if [ -d "$BACKUP_DEST" ]; then
    cp -u "$BACKUP_FILE" "${BACKUP_DEST}/backup-${HOSTNAME}-${FW_LABEL}-$(date +%F).tar.gz"
    cp -u "$BACKUP_FILE" "${BACKUP_DEST}/backup_to_restore.tar.gz"

    # Copy AdGuardHome config (GL.iNet path)
    cp -u /etc/AdGuardHome/config.* "${BACKUP_DEST}/" 2>/dev/null
    # Copy AdGuardHome config (OpenWrt nativo path)
    [ -f /etc/adguardhome/adguardhome.yaml ] && cp -u /etc/adguardhome/adguardhome.yaml "${BACKUP_DEST}/"

    # Copy packages list
    PKGFILE="/etc/config/my_installed_packages"
    [ -f "$PKGFILE" ] && cp -u "$PKGFILE" "${BACKUP_DEST}/packages-${HOSTNAME}-${OPENWRT_VERSION}-$(date +%F).txt"

    [ -f /root/AdGuardHome_backup.tar.gz ] && cp -u /root/AdGuardHome_backup.tar.gz "${BACKUP_DEST}/"
    cp -r -u /etc/script/ "${BACKUP_DEST}/"
    cp -r -u /etc/init.d/ "${BACKUP_DEST}/"

    # Generate Backup Log
    sysupgrade -l "$BACKUP_FILE" > "${BACKUP_DEST}/respaldo-${FW_LABEL}.txt"

    # Dashboard y Monitoreo (opcional, si existen)
    cp -r -u /www/dashboard/ "${BACKUP_DEST}/" 2>/dev/null
    cp -u /www/cgi-bin/dashboard_api.sh "${BACKUP_DEST}/" 2>/dev/null
    cp -r -u /usr/bin/monitor/ "${BACKUP_DEST}/" 2>/dev/null
    cp -r -u /etc/monitor/ "${BACKUP_DEST}/" 2>/dev/null
    cp -u /etc/nginx/conf.d/dashboard.conf "${BACKUP_DEST}/" 2>/dev/null
else
    logger -p local0.info -t backup-new "ADVERTENCIA: Destino $BACKUP_DEST no disponible"
fi

BACKUP_SIZE="$(ls -lh "$BACKUP_FILE" | awk '{print $5}')"

send_to_telegram "#$(echo "${HOSTNAME}" | sed 's/[^a-zA-Z0-9]//g') Respaldo completado
Time: $(date '+%A %d-%b-%Y %T')
Archivo: ${BACKUP_FILE##*/}
Tamaño: ${BACKUP_SIZE}
OpenWrt: ${OPENWRT_VERSION}${GLINET_VERSION:+
GL\.iNet: ${GLINET_VERSION}}
Destino: ${BACKUP_DEST}"

# Execute Cleanup Script
[ -x /etc/script/borrar.sh ] && /etc/script/borrar.sh
