#!/bin/sh
# Monitor de Servicios - Formato mejorado

. /etc/monitor/config.sh 2>/dev/null || {
    SERVICIOS_CRITICOS="dnsmasq dropbear odhcpd"
}

TAG="monitor_servicios"
ESTADO_DIR="/tmp/monitor/servicios"
mkdir -p "$ESTADO_DIR"

ALERTAS=""
FECHA=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || echo "OpenWrt")

for SERVICIO in $SERVICIOS_CRITICOS; do
    ESTADO_ARCHIVO="$ESTADO_DIR/${SERVICIO}_estado"
    
    if pidof "$SERVICIO" > /dev/null 2>&1; then
        ESTADO_ACTUAL="activo"
    else
        ESTADO_ACTUAL="caido"
    fi
    
    ESTADO_ANTERIOR="activo"
    [ -f "$ESTADO_ARCHIVO" ] && ESTADO_ANTERIOR=$(cat "$ESTADO_ARCHIVO")
    
    echo "$ESTADO_ACTUAL" > "$ESTADO_ARCHIVO"
    
    if [ "$ESTADO_ACTUAL" = "caido" ] && [ "$ESTADO_ANTERIOR" = "activo" ]; then
        ALERTAS="${ALERTAS}    ❌ <code>$SERVICIO</code> se detuvo
"
        logger -t "$TAG" "ALERTA: $SERVICIO se detuvo"
        
        # Reiniciar
        if [ -f "/etc/init.d/$SERVICIO" ]; then
            /etc/init.d/"$SERVICIO" restart > /dev/null 2>&1
            sleep 2
            if pidof "$SERVICIO" > /dev/null 2>&1; then
                ALERTAS="${ALERTAS}    🔄 <code>$SERVICIO</code> reiniciado OK
"
                echo "activo" > "$ESTADO_ARCHIVO"
            else
                ALERTAS="${ALERTAS}    ⚠️ <code>$SERVICIO</code> no pudo reiniciarse
"
            fi
        fi
    elif [ "$ESTADO_ACTUAL" = "activo" ] && [ "$ESTADO_ANTERIOR" = "caido" ]; then
        ALERTAS="${ALERTAS}    ✅ <code>$SERVICIO</code> activo nuevamente
"
    fi
done

# Notificar
if [ -n "$ALERTAS" ]; then
    MENSAJE="⚙️ <b>ALERTA SERVICIOS</b>
━━━━━━━━━━━━━━━━━━━━
🏠 <b>$HOSTNAME</b>
🕐 $FECHA

<b>Cambios detectados:</b>
$ALERTAS"
    /usr/bin/monitor/notificar.sh "$MENSAJE"
fi

# Verbose
if [ "$1" = "-v" ]; then
    echo "=== Estado de Servicios ==="
    for SERVICIO in $SERVICIOS_CRITICOS; do
        if pidof "$SERVICIO" > /dev/null 2>&1; then
            echo "OK $SERVICIO: Activo"
        else
            echo "XX $SERVICIO: Caido"
        fi
    done
fi
