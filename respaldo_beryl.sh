#!/bin/sh
# Backup script para Beryl AX (GL-MT3000)
# Instalado en: /etc/script/respaldo.sh
# Crontab: 0 0 */3 * * /etc/script/respaldo.sh

TOKEN="REDACTED_BOT_TOKEN"
CHAT_ID="716542586"
BACKUP_DEST="/tmp/mountd/disk1_part1/beryl"

send_to_telegram() {
    logger -p local0.info -t backup-beryl "$1"
    [ -n "$TOKEN" ] && [ -n "$CHAT_ID" ] || return
    curl --silent --show-error --max-time 10 \
        --data "disable_notification=false" \
        --data "parse_mode=MarkdownV2" \
        --data "chat_id=$CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TOKEN}/sendMessage" > /dev/null
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

umask go=

# Guardar lista de paquetes
[ -x /etc/script/pkg_manager.sh ] && /etc/script/pkg_manager.sh save 2>/dev/null \
    || [ -x /etc/script/packages.sh ] && /etc/script/packages.sh 2>/dev/null

# Crear backup
BACKUP_FILE="/tmp/backup-${HOSTNAME}-${FW_LABEL}-$(date +%F).tar.gz"
sysupgrade -b "$BACKUP_FILE"

if [ ! -f "$BACKUP_FILE" ]; then
    logger -p local0.info -t backup-beryl "Error: Backup file not created"
    send_to_telegram "\#$(echo "${HOSTNAME}" | sed 's/[^a-zA-Z0-9]//g') ERROR backup \#
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Error: No se pudo crear el backup
\`\`\`"
    exit 1
fi

# Copiar al USB
if [ -d "$BACKUP_DEST" ]; then
    cp -u "$BACKUP_FILE" "${BACKUP_DEST}/backup-${HOSTNAME}-${FW_LABEL}-$(date +%F).tar.gz"
    cp -u "$BACKUP_FILE" "${BACKUP_DEST}/backup_to_restore-${FW_LABEL}.tar.gz"
    cp -r -u /etc/script/ "${BACKUP_DEST}/"
    cp -r -u /etc/init.d/ "${BACKUP_DEST}/"
    sysupgrade -l "$BACKUP_FILE" > "${BACKUP_DEST}/respaldo-${FW_LABEL}.txt"

    # Lista de paquetes
    PKGFILE="/tmp/packages-${HOSTNAME}-${OPENWRT_VERSION}-$(date +%F).txt"
    [ -f "$PKGFILE" ] && cp -u "$PKGFILE" "${BACKUP_DEST}/"
else
    logger -p local0.info -t backup-beryl "ADVERTENCIA: $BACKUP_DEST no disponible"
fi

BACKUP_SIZE="$(ls -lh "$BACKUP_FILE" | awk '{print $5}')"

# Escapar puntos para MarkdownV2
OWRT_ESC="$(echo "$OPENWRT_VERSION" | sed 's/\./\\./g; s/-/\\-/g')"
GL_ESC="$(echo "$GLINET_VERSION" | sed 's/\./\\./g; s/-/\\-/g')"
FILE_ESC="$(echo "${BACKUP_FILE##*/}" | sed 's/\./\\./g; s/-/\\-/g')"

GL_LINE=""
[ -n "$GLINET_VERSION" ] && GL_LINE="
GL\.iNet: ${GL_ESC}"

send_to_telegram "\#$(echo "${HOSTNAME}" | sed 's/[^a-zA-Z0-9]//g') RESPALDO LISTO \#
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Archivo: ${FILE_ESC}
Tamaño: ${BACKUP_SIZE}
OpenWrt: ${OWRT_ESC}${GL_LINE}
\`\`\`"

[ -x /etc/script/borrar.sh ] && /etc/script/borrar.sh
