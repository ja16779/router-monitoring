#!/bin/sh

# Configuración de Telegram
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
TELEGRAM_URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# Función para enviar mensaje a Telegram
send_telegram_message() {
    local message="$1"
    curl -s -X POST "$TELEGRAM_URL" -d chat_id="$ID" -d text="$message"
}

# Parámetros de conexión
INTERFACE="pppoe-wan"
PROVEEDOR="Telmex"
TARGET="8.8.8.8"
HOSTNAME="$(uname -n)"

# Ejecutar prueba de conexión con ping
if ping -c 1 -w 2 -I "$INTERFACE" "$TARGET" > /dev/null; then
    STATUS_MSG="$HOSTNAME: Conexión a Internet FUNCIONA en $INTERFACE ($PROVEEDOR)"
else
    STATUS_MSG="$HOSTNAME: Sin conexión a Internet en $INTERFACE ($PROVEEDOR)"
fi

# Enviar notificación a Telegram
send_telegram_message "$STATUS_MSG"

# (Opcional) Registrar en archivo local
LOGFILE="/var/log/internet_status.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - $STATUS_MSG" >> "$LOGFILE"
