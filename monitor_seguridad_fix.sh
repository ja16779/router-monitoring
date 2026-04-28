#!/bin/sh
# Monitor de Seguridad - Formato mejorado

. /etc/monitor/config.sh 2>/dev/null || {
    UMBRAL_SSH_INTENTOS=5
    ARCHIVO_DISPOSITIVOS_CONOCIDOS="/etc/monitor/dispositivos_conocidos.txt"
}

TAG="monitor_seguridad"
mkdir -p /tmp/monitor /etc/monitor/hashes
touch "$ARCHIVO_DISPOSITIVOS_CONOCIDOS"

ALERTAS=""
FECHA=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || echo "OpenWrt")

# Intentos SSH
SSH_INTENTOS=$(logread 2>/dev/null | grep -cE "Failed password|authentication failure|Invalid user" || echo 0)

if [ "$SSH_INTENTOS" -gt "$UMBRAL_SSH_INTENTOS" ]; then
    ALERTAS="${ALERTAS}    🔐 <code>$SSH_INTENTOS</code> intentos SSH fallidos
"
    logger -t "$TAG" "ALERTA: $SSH_INTENTOS intentos SSH fallidos"
fi

# Nuevos dispositivos
if [ -f /tmp/dhcp.leases ]; then
    while read EXPIRE MAC IP HOSTNAME_DEV CLIENT_ID; do
        if ! grep -qi "$MAC" "$ARCHIVO_DISPOSITIVOS_CONOCIDOS" 2>/dev/null; then
            HOSTNAME_DEV=${HOSTNAME_DEV:-"desconocido"}
            ALERTAS="${ALERTAS}    📱 Nuevo: <code>$MAC</code>
        IP: <code>$IP</code>
        Nombre: <code>$HOSTNAME_DEV</code>
"
            logger -t "$TAG" "Nuevo dispositivo: $MAC - $IP"
            echo "$MAC" >> "$ARCHIVO_DISPOSITIVOS_CONOCIDOS"
        fi
    done < /tmp/dhcp.leases
fi

# IPs con muchas conexiones
if [ -f /proc/net/nf_conntrack ]; then
    cat /proc/net/nf_conntrack 2>/dev/null | \
        grep -oE 'src=[0-9.]+' | cut -d'=' -f2 | \
        sort | uniq -c | sort -rn | head -5 | \
        while read CUENTA IP; do
            case "$IP" in
                192.168.*|10.*|172.16.*|127.*) continue ;;
            esac
            if [ "$CUENTA" -gt 100 ]; then
                echo "    🌐 IP externa: <code>$IP</code> ($CUENTA conexiones)" >> /tmp/monitor/ip_alerta.tmp
            fi
        done

    if [ -f /tmp/monitor/ip_alerta.tmp ]; then
        ALERTAS="${ALERTAS}$(cat /tmp/monitor/ip_alerta.tmp)
"
        rm /tmp/monitor/ip_alerta.tmp
    fi
fi

# Integridad archivos
ARCHIVOS_CRITICOS="/etc/passwd /etc/shadow /etc/config/firewall /etc/config/wireless"

for ARCHIVO in $ARCHIVOS_CRITICOS; do
    if [ -f "$ARCHIVO" ]; then
        NOMBRE=$(echo "$ARCHIVO" | tr '/' '_')
        HASH_ACTUAL=$(md5sum "$ARCHIVO" 2>/dev/null | awk '{print $1}')
        HASH_FILE="/etc/monitor/hashes/${NOMBRE}.md5"

        if [ -f "$HASH_FILE" ]; then
            HASH_GUARDADO=$(cat "$HASH_FILE")
            if [ "$HASH_ACTUAL" != "$HASH_GUARDADO" ]; then
                ALERTAS="${ALERTAS}    📄 Archivo modificado: <code>$ARCHIVO</code>
"
                logger -t "$TAG" "ALERTA: $ARCHIVO modificado"
            fi
        fi
        echo "$HASH_ACTUAL" > "$HASH_FILE"
    fi
done

# Notificar
if [ -n "$ALERTAS" ]; then
    MENSAJE="🔒 <b>ALERTA SEGURIDAD</b>
━━━━━━━━━━━━━━━━━━━━
🏠 <b>$HOSTNAME</b>
🕐 $FECHA

<b>Eventos detectados:</b>
$ALERTAS"
    /usr/bin/monitor/notificar.sh "$MENSAJE"
fi

# Verbose
if [ "$1" = "-v" ]; then
    echo "=== Seguridad ==="
    echo "Intentos SSH fallidos: $SSH_INTENTOS"
    [ -n "$ALERTAS" ] && echo "Alertas detectadas"
fi
