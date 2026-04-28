#!/bin/sh
# Monitor de Internet - Formato mejorado

. /etc/monitor/config.sh 2>/dev/null || {
    HOSTS_PING="8.8.8.8 1.1.1.1"
    UMBRAL_LATENCIA=100
}

TAG="monitor_internet"
ESTADO_ARCHIVO="/tmp/monitor/internet_estado"
mkdir -p /tmp/monitor

# Verificar conectividad
FALLOS=0
EXITOS=0
LATENCIA_TOTAL=0

for HOST in $HOSTS_PING; do
    RESULTADO=$(ping -c 2 -W 5 "$HOST" 2>/dev/null)
    if [ $? -eq 0 ]; then
        EXITOS=$((EXITOS + 1))
        LAT=$(echo "$RESULTADO" | tail -1 | awk -F'/' '{printf "%.0f", $5}')
        [ -n "$LAT" ] && LATENCIA_TOTAL=$((LATENCIA_TOTAL + LAT))
    else
        FALLOS=$((FALLOS + 1))
    fi
done

# Latencia promedio
if [ "$EXITOS" -gt 0 ]; then
    LATENCIA=$((LATENCIA_TOTAL / EXITOS))
else
    LATENCIA=0
fi

# Estado anterior
ESTADO_ANTERIOR="conectado"
[ -f "$ESTADO_ARCHIVO" ] && ESTADO_ANTERIOR=$(cat "$ESTADO_ARCHIVO")

# Estado actual
if [ "$EXITOS" -eq 0 ]; then
    ESTADO_ACTUAL="desconectado"
else
    ESTADO_ACTUAL="conectado"
fi

echo "$ESTADO_ACTUAL" > "$ESTADO_ARCHIVO"

FECHA=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || echo "OpenWrt")

# Notificar cambios
if [ "$ESTADO_ACTUAL" = "desconectado" ] && [ "$ESTADO_ANTERIOR" = "conectado" ]; then
    logger -t "$TAG" "ALERTA: Conexion a Internet PERDIDA"
    MENSAJE="🔴 <b>INTERNET CAÍDO</b>
━━━━━━━━━━━━━━━━━━━━
🏠 <b>$HOSTNAME</b>
🕐 $FECHA

❌ <b>Sin conexión a Internet</b>

📡 Hosts probados:
    • 8.8.8.8 (Google)
    • 1.1.1.1 (Cloudflare)

⚠️ Verificando conectividad..."
    /usr/bin/monitor/notificar.sh "$MENSAJE"

elif [ "$ESTADO_ACTUAL" = "conectado" ] && [ "$ESTADO_ANTERIOR" = "desconectado" ]; then
    logger -t "$TAG" "INFO: Conexion a Internet RESTAURADA"
    MENSAJE="🟢 <b>INTERNET RESTAURADO</b>
━━━━━━━━━━━━━━━━━━━━
🏠 <b>$HOSTNAME</b>
🕐 $FECHA

✅ <b>Conexión restablecida</b>

📶 Latencia: <code>${LATENCIA}ms</code>
📡 Hosts OK: <code>$EXITOS</code>"
    /usr/bin/monitor/notificar.sh "$MENSAJE"
fi

# Latencia alta
if [ "$ESTADO_ACTUAL" = "conectado" ] && [ "$LATENCIA" -gt "$UMBRAL_LATENCIA" ]; then
    logger -t "$TAG" "ALERTA: Latencia alta ${LATENCIA}ms"
    MENSAJE="🟡 <b>LATENCIA ALTA</b>
━━━━━━━━━━━━━━━━━━━━
🏠 <b>$HOSTNAME</b>
🕐 $FECHA

⚠️ Latencia: <code>${LATENCIA}ms</code>
📊 Umbral: <code>${UMBRAL_LATENCIA}ms</code>"
    /usr/bin/monitor/notificar.sh "$MENSAJE" 1
fi

# Verbose
if [ "$1" = "-v" ]; then
    echo "Estado: $ESTADO_ACTUAL"
    echo "Latencia: ${LATENCIA}ms"
    echo "Hosts OK: $EXITOS / Fallidos: $FALLOS"
fi
