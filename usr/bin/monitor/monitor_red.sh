#!/bin/sh
# Monitor de Red - Formato mejorado

. /etc/monitor/config.sh 2>/dev/null || {
    INTERFAZ_WAN="pppoe-wan"
    UMBRAL_CONEXIONES=500
}

TAG="monitor_red"
mkdir -p /tmp/monitor

ALERTAS=""
FECHA=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || echo "OpenWrt")

# Interfaces caidas
for IFACE in pppoe-wan lan5 br-lan lan1; do
    if [ -d "/sys/class/net/$IFACE" ]; then
        ESTADO=$(cat /sys/class/net/$IFACE/operstate 2>/dev/null)
        ESTADO_ARCHIVO="/tmp/monitor/iface_${IFACE}_estado"
        
        ESTADO_ANTERIOR="up"
        [ -f "$ESTADO_ARCHIVO" ] && ESTADO_ANTERIOR=$(cat "$ESTADO_ARCHIVO")
        
        echo "$ESTADO" > "$ESTADO_ARCHIVO"
        
        if [ "$ESTADO" = "down" ] && [ "$ESTADO_ANTERIOR" = "up" ]; then
            ALERTAS="${ALERTAS}    🔴 <code>$IFACE</code> caída
"
            logger -t "$TAG" "ALERTA: Interfaz $IFACE caida"
        elif [ "$ESTADO" = "up" ] && [ "$ESTADO_ANTERIOR" = "down" ]; then
            ALERTAS="${ALERTAS}    🟢 <code>$IFACE</code> restaurada
"
        fi
    fi
done

# Conexiones activas
CONEXIONES=0
if [ -f /proc/net/nf_conntrack ]; then
    CONEXIONES=$(wc -l < /proc/net/nf_conntrack)
    if [ "$CONEXIONES" -gt "$UMBRAL_CONEXIONES" ]; then
        ALERTAS="${ALERTAS}    ⚠️ Conexiones: <code>$CONEXIONES</code> (umbral: $UMBRAL_CONEXIONES)
"
        logger -t "$TAG" "ALERTA: $CONEXIONES conexiones activas"
    fi
fi

# Clientes WiFi
WIFI_TOTAL=0
if command -v iwinfo > /dev/null 2>&1; then
    for IFACE in $(iwinfo 2>/dev/null | grep ESSID | awk '{print $1}'); do
        CLIENTES=$(iwinfo "$IFACE" assoclist 2>/dev/null | grep -c "dBm")
        WIFI_TOTAL=$((WIFI_TOTAL + CLIENTES))
    done
fi

# Clientes DHCP
DHCP_TOTAL=0
[ -f /tmp/dhcp.leases ] && DHCP_TOTAL=$(wc -l < /tmp/dhcp.leases)

# Guardar estado
cat > /tmp/monitor/red_status.txt << EOFSTATUS
Actualizacion: $FECHA
Conexiones: $CONEXIONES
Clientes WiFi: $WIFI_TOTAL
Clientes DHCP: $DHCP_TOTAL
EOFSTATUS

# Notificar
if [ -n "$ALERTAS" ]; then
    MENSAJE="🌐 <b>ALERTA RED</b>
━━━━━━━━━━━━━━━━━━━━
🏠 <b>$HOSTNAME</b>
🕐 $FECHA

<b>Cambios detectados:</b>
$ALERTAS
📊 <b>Estado actual:</b>
    🔗 Conexiones: <code>$CONEXIONES</code>
    📱 WiFi: <code>$WIFI_TOTAL</code>
    🖥 DHCP: <code>$DHCP_TOTAL</code>"
    /usr/bin/monitor/notificar.sh "$MENSAJE"
fi

# Verbose
if [ "$1" = "-v" ]; then
    cat /tmp/monitor/red_status.txt
    [ -n "$ALERTAS" ] && echo "Alertas detectadas"
fi
