#!/bin/sh
# Prueba de Telegram - Formato mejorado

echo "=== Prueba de Telegram ==="
echo ""

if [ -f /etc/monitor/config.sh ]; then
    . /etc/monitor/config.sh
    echo "Configuracion cargada"
else
    echo "ERROR: No se encontro /etc/monitor/config.sh"
    exit 1
fi

echo ""
echo "Verificando configuracion..."
echo "  TELEGRAM_ACTIVO: $TELEGRAM_ACTIVO"
echo "  TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN:0:15}..."
echo "  TELEGRAM_CHAT_ID: $TELEGRAM_CHAT_ID"
echo ""

if [ "$TELEGRAM_BOT_TOKEN" = "TU_BOT_TOKEN_AQUI" ]; then
    echo "ERROR: Debes configurar TELEGRAM_BOT_TOKEN"
    exit 1
fi

if [ "$TELEGRAM_CHAT_ID" = "TU_CHAT_ID_AQUI" ]; then
    echo "ERROR: Debes configurar TELEGRAM_CHAT_ID"
    exit 1
fi

if ! command -v curl > /dev/null 2>&1; then
    echo "ERROR: curl no instalado"
    exit 1
fi
echo "curl: OK"

echo ""
echo "Verificando conectividad..."
if ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
    echo "Internet: OK"
else
    echo "ERROR: Sin conexion a Internet"
    exit 1
fi

echo ""
echo "Enviando mensaje de prueba..."

HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || echo "OpenWrt")
FECHA=$(date '+%Y-%m-%d %H:%M:%S')
VERSION=$(cat /etc/openwrt_release 2>/dev/null | grep DISTRIB_RELEASE | cut -d"'" -f2)

MENSAJE="🔔 <b>PRUEBA DE MONITOREO</b>
━━━━━━━━━━━━━━━━━━━━
✅ Telegram configurado correctamente

🏠 <b>Dispositivo:</b> <code>$HOSTNAME</code>
📦 <b>OpenWrt:</b> <code>$VERSION</code>
🕐 <b>Hora:</b> <code>$FECHA</code>

📊 Sistema de monitoreo activo:
    • Internet cada 1 min
    • Servicios cada 1 min
    • Sistema cada 5 min
    • Red cada 15 min
    • Seguridad cada hora
    • Reporte diario 7:00 AM"

RESPUESTA=$(curl -s -X POST     --connect-timeout 10     --max-time 30     "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"     -d "chat_id=${TELEGRAM_CHAT_ID}"     -d "text=${MENSAJE}"     -d "parse_mode=HTML" 2>&1)

if echo "$RESPUESTA" | grep -q '"ok":true'; then
    echo ""
    echo "EXITO: Mensaje enviado correctamente"
    echo "Revisa tu Telegram"
else
    echo ""
    echo "ERROR al enviar mensaje"
    echo "Respuesta: $RESPUESTA"
fi
