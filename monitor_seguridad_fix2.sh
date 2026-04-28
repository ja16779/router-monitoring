#!/bin/sh
. /etc/monitor/config.sh 2>/dev/null || { UMBRAL_SSH_INTENTOS=5; ARCHIVO_DISPOSITIVOS_CONOCIDOS="/etc/monitor/dispositivos_conocidos.txt"; }

TAG="monitor_seguridad"
mkdir -p /tmp/monitor /etc/monitor/hashes
touch "$ARCHIVO_DISPOSITIVOS_CONOCIDOS"

ALERTAS=""
FECHA=$(date "+%Y-%m-%d %H:%M:%S")
HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || echo "OpenWrt")

SSH_INTENTOS=$(logread 2>/dev/null | grep -cE "Failed password|authentication failure|Invalid user" || echo 0)
[ "$SSH_INTENTOS" -gt "$UMBRAL_SSH_INTENTOS" ] && ALERTAS="${ALERTAS}    🔐 <code>$SSH_INTENTOS</code> intentos SSH fallidos
"

if [ -f /tmp/dhcp.leases ]; then
    while read EXPIRE MAC IP HOSTNAME_DEV CLIENT_ID; do
        if ! grep -qi "$MAC" "$ARCHIVO_DISPOSITIVOS_CONOCIDOS" 2>/dev/null; then
            HOSTNAME_DEV=${HOSTNAME_DEV:-"desconocido"}
            ALERTAS="${ALERTAS}    📱 Nuevo: <code>$MAC</code> ($IP - $HOSTNAME_DEV)
"
            echo "$MAC" >> "$ARCHIVO_DISPOSITIVOS_CONOCIDOS"
        fi
    done < /tmp/dhcp.leases
fi

ARCHIVOS="/etc/passwd /etc/shadow /etc/config/firewall /etc/config/wireless"
for ARCHIVO in $ARCHIVOS; do
    if [ -f "$ARCHIVO" ]; then
        NOMBRE=$(echo "$ARCHIVO" | tr "/" "_")
        HASH_ACTUAL=$(md5sum "$ARCHIVO" 2>/dev/null | awk "{print \$1}")
        HASH_FILE="/etc/monitor/hashes/${NOMBRE}.md5"
        [ -f "$HASH_FILE" ] && [ "$HASH_ACTUAL" != "$(cat $HASH_FILE)" ] && ALERTAS="${ALERTAS}    📄 Modificado: <code>$ARCHIVO</code>
"
        echo "$HASH_ACTUAL" > "$HASH_FILE"
    fi
done

if [ -n "$ALERTAS" ]; then
    MENSAJE="🔒 <b>ALERTA SEGURIDAD</b>
━━━━━━━━━━━━━━━━━━━━
🏠 <b>$HOSTNAME</b>
🕐 $FECHA

<b>Eventos:</b>
$ALERTAS"
    /usr/bin/monitor/notificar.sh "$MENSAJE"
fi

[ "$1" = "-v" ] && echo "SSH intentos: $SSH_INTENTOS"
