#!/bin/sh
# Monitor de Sistema - Formato mejorado

. /etc/monitor/config.sh 2>/dev/null || {
    UMBRAL_CPU=80
    UMBRAL_RAM=85
    UMBRAL_DISCO=90
    UMBRAL_TEMP=70
}

TAG="monitor_sistema"
ALERTAS=""

# CPU
CPU1=$(cat /proc/stat | grep '^cpu ' | awk '{print $2+$3+$4+$5+$6+$7+$8}')
IDLE1=$(cat /proc/stat | grep '^cpu ' | awk '{print $5}')
sleep 1
CPU2=$(cat /proc/stat | grep '^cpu ' | awk '{print $2+$3+$4+$5+$6+$7+$8}')
IDLE2=$(cat /proc/stat | grep '^cpu ' | awk '{print $5}')

CPU_DIFF=$((CPU2 - CPU1))
IDLE_DIFF=$((IDLE2 - IDLE1))

if [ "$CPU_DIFF" -gt 0 ]; then
    USO_CPU=$((100 * (CPU_DIFF - IDLE_DIFF) / CPU_DIFF))
else
    USO_CPU=0
fi

if [ "$USO_CPU" -gt "$UMBRAL_CPU" ]; then
    ALERTAS="${ALERTAS}    🔴 CPU: <code>${USO_CPU}%</code> (umbral: ${UMBRAL_CPU}%)
"
    logger -t "$TAG" "ALERTA: CPU al ${USO_CPU}%"
fi

# RAM
MEMINFO=$(cat /proc/meminfo)
TOTAL=$(echo "$MEMINFO" | grep MemTotal | awk '{print $2}')
AVAILABLE=$(echo "$MEMINFO" | grep MemAvailable | awk '{print $2}')
if [ -z "$AVAILABLE" ]; then
    FREE=$(echo "$MEMINFO" | grep MemFree | awk '{print $2}')
    BUFFERS=$(echo "$MEMINFO" | grep Buffers | awk '{print $2}')
    CACHED=$(echo "$MEMINFO" | grep "^Cached:" | awk '{print $2}')
    AVAILABLE=$((FREE + BUFFERS + CACHED))
fi
USADO=$((TOTAL - AVAILABLE))
USO_RAM=$((USADO * 100 / TOTAL))

if [ "$USO_RAM" -gt "$UMBRAL_RAM" ]; then
    ALERTAS="${ALERTAS}    🔴 RAM: <code>${USO_RAM}%</code> (umbral: ${UMBRAL_RAM}%)
"
    logger -t "$TAG" "ALERTA: RAM al ${USO_RAM}%"
fi

# Temperatura
TEMP=0
for SENSOR in /sys/class/thermal/thermal_zone*/temp; do
    if [ -f "$SENSOR" ]; then
        T=$(cat "$SENSOR" 2>/dev/null)
        if [ -n "$T" ] && [ "$T" -gt 1000 ]; then
            T=$((T / 1000))
        fi
        [ "$T" -gt "$TEMP" ] && TEMP=$T
    fi
done

if [ "$TEMP" -gt "$UMBRAL_TEMP" ]; then
    ALERTAS="${ALERTAS}    🔥 Temperatura: <code>${TEMP}°C</code> (umbral: ${UMBRAL_TEMP}°C)
"
    logger -t "$TAG" "ALERTA: Temperatura ${TEMP}C"
fi

# Guardar estado
mkdir -p /tmp/monitor
FECHA=$(date '+%Y-%m-%d %H:%M:%S')

cat > /tmp/monitor/sistema_status.txt << EOFSTATUS
Ultima actualizacion: $FECHA
CPU: ${USO_CPU}%
RAM: ${USO_RAM}%
Temperatura: ${TEMP}C
EOFSTATUS

# Notificar
if [ -n "$ALERTAS" ]; then
    HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || echo "OpenWrt")
    MENSAJE="⚠️ <b>ALERTA SISTEMA</b>
━━━━━━━━━━━━━━━━━━━━
🏠 <b>$HOSTNAME</b>
🕐 $FECHA

<b>Recursos críticos:</b>
$ALERTAS
📊 Estado actual:
    CPU: <code>${USO_CPU}%</code>
    RAM: <code>${USO_RAM}%</code>
    Temp: <code>${TEMP}°C</code>"
    
    /usr/bin/monitor/notificar.sh "$MENSAJE"
fi

# Verbose
if [ "$1" = "-v" ]; then
    echo "CPU: ${USO_CPU}%"
    echo "RAM: ${USO_RAM}%"
    echo "Temp: ${TEMP}C"
    [ -n "$ALERTAS" ] && echo -e "\nALERTAS detectadas"
fi
