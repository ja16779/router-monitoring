#!/bin/sh
# Script de respaldo para OpenWRT
# Crea backup, copia a disco externo y notifica por Telegram

LOGTAG="backup"
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID="716542586"
BACKUP_DEST=""

# Detectar configuracion segun router
case "$(uname -n)" in
    GL-MT6000)
        TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
        # OpenWrt nativo: /mnt/sda1 | GL.iNet: /tmp/mountd/disk2_part1
        if [ -d "/mnt/sda1" ]; then
            BACKUP_DEST="/mnt/sda1"
        else
            BACKUP_DEST="/tmp/mountd/disk2_part1"
        fi
        ;;
    GL-MT3000*)
        TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
        BACKUP_DEST="/tmp/mountd/disk1_part1/beryl"
        ;;
esac

# Enviar mensaje a Telegram
send_telegram() {
    local message="$1"

    logger -p local0.info -t "$LOGTAG" "$message"

    [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && return

    curl -skim 10 \
        --data disable_notification="false" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$message" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

# Obtener versiones
OPENWRT_VERSION="$(grep DISTRIB_RELEASE /etc/openwrt_release | cut -d'=' -f2 | tr -d "'")"
GLINET_VERSION="$(cat /etc/glversion 2>/dev/null)"
DATE_STAMP="$(date +%F)"
TIMESTAMP="$(date '+%A %d-%b-%Y %T')"

# Etiqueta de version para nombre de archivo
if [ -n "$GLINET_VERSION" ]; then
    FW_LABEL="${OPENWRT_VERSION}-gl${GLINET_VERSION}"
else
    FW_LABEL="${OPENWRT_VERSION}"
fi

# Configurar permisos
umask go=

# Crear backup
BACKUP_FILE="/tmp/backup-${HOSTNAME}-${FW_LABEL}-${DATE_STAMP}.tar.gz"
sysupgrade -b "$BACKUP_FILE"

if [ ! -f "$BACKUP_FILE" ]; then
    logger -t "$LOGTAG" "ERROR: No se pudo crear el backup"
    send_telegram "<b>ERROR Backup</b>
<pre>
Router: $(uname -n)
Time: ${TIMESTAMP}
Error: No se pudo crear el archivo de backup
</pre>"
    exit 1
fi

# Generar lista de paquetes
/etc/script/packages.sh 2>/dev/null

# Copiar archivos al destino
if [ -d "$BACKUP_DEST" ]; then
    cp -u "$BACKUP_FILE" "${BACKUP_DEST}/"
    cp -u "$BACKUP_FILE" "${BACKUP_DEST}/backup_to_restore-${FW_LABEL}.tar.gz"

    # Copiar lista de paquetes
    [ -f "/tmp/packages-${HOSTNAME}-${OPENWRT_VERSION}-${DATE_STAMP}.txt" ] && \
        cp -u "/tmp/packages-${HOSTNAME}-${OPENWRT_VERSION}-${DATE_STAMP}.txt" "${BACKUP_DEST}/"

    # Copiar configuraciones adicionales
    # GL.iNet: /etc/AdGuardHome/config.yaml
    cp -u /etc/AdGuardHome/config.* "${BACKUP_DEST}/" 2>/dev/null
    # OpenWrt nativo: /etc/adguardhome/adguardhome.yaml
    [ -f /etc/adguardhome/adguardhome.yaml ] && cp -u /etc/adguardhome/adguardhome.yaml "${BACKUP_DEST}/"
    [ -f /root/AdGuardHome_backup.tar.gz ] && cp -u /root/AdGuardHome_backup.tar.gz "${BACKUP_DEST}/"

    # Copiar scripts e init.d
    cp -r -u /etc/script/ "${BACKUP_DEST}/"
    cp -r -u /etc/init.d/ "${BACKUP_DEST}/"

    # Generar lista de archivos del backup
    sysupgrade -l "$BACKUP_FILE" > "${BACKUP_DEST}/respaldo-${FW_LABEL}.txt"
else
    logger -t "$LOGTAG" "ADVERTENCIA: Destino $BACKUP_DEST no disponible"
fi

# Notificar exito
BACKUP_SIZE="$(ls -lh "$BACKUP_FILE" | awk '{print $5}')"

send_telegram "<b>#$(echo "${HOSTNAME}" | sed 's/[^a-zA-Z0-9]//g')</b> Respaldo completado
<pre>
Time: ${TIMESTAMP}
Archivo: ${BACKUP_FILE##*/}
Tamaño: ${BACKUP_SIZE}
OpenWrt: ${OPENWRT_VERSION}${GLINET_VERSION:+
GL.iNet: ${GLINET_VERSION}}
Destino: ${BACKUP_DEST}
</pre>"

# Ejecutar limpieza
[ -x /etc/script/borrar.sh ] && /etc/script/borrar.sh
