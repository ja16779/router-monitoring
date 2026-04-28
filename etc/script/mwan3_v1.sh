#!/bin/sh
#############################################
# Network Connection Notifier v2.0
# Notifica conexiones/desconexiones de red vía Telegram
#############################################

# ============================================
# CONFIGURACIÓN
# ============================================

# Telegram credentials
readonly TOKEN="REDACTED_BOT_TOKEN"
readonly CHAT_ID="716542586"
readonly TELEGRAM_URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# Timeout para requests (segundos)
readonly CURL_TIMEOUT=10
readonly IP_CHECK_TIMEOUT=5

# Archivo de estado para rate limiting
readonly STATE_FILE="/tmp/network_notify_state"
readonly MIN_NOTIFICATION_INTERVAL=60  # 1 minuto mínimo entre notificaciones

# ============================================
# VARIABLES DE ENTORNO
# ============================================

ACTION="${ACTION:-unknown}"
INTERFACE="${INTERFACE:-unknown}"
DEVICE="${DEVICE:-unknown}"
HOSTNAME="$(uci get system.@system[0].hostname 2>/dev/null || echo 'OpenWrt')"

# ============================================
# FUNCIONES
# ============================================

# Obtener IP pública de manera segura
get_public_ip() {
    local device="$1"
    local ip=""
    
    # Lista de servicios para verificar IP (fallback)
    local services="http://ifconfig.me http://icanhazip.com http://ipecho.net/plain"
    
    for service in $services; do
        if [ -n "$device" ]; then
            ip=$(curl --interface "$device" -s --connect-timeout "$IP_CHECK_TIMEOUT" "$service" 2>/dev/null)
        else
            ip=$(curl -s --connect-timeout "$IP_CHECK_TIMEOUT" "$service" 2>/dev/null)
        fi
        
        # Validar que sea una IP válida
        if echo "$ip" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
            echo "$ip"
            return 0
        fi
    done
    
    echo "No disponible"
    return 1
}

# Verificar rate limiting
should_notify() {
    local key="$1"
    local current_time=$(date +%s)
    local last_time=0
    
    # Crear archivo si no existe
    touch "$STATE_FILE" 2>/dev/null
    
    # Leer último timestamp
    if [ -f "$STATE_FILE" ]; then
        last_time=$(grep "^$key:" "$STATE_FILE" 2>/dev/null | cut -d: -f2)
        [ -z "$last_time" ] && last_time=0
    fi
    
    local diff=$((current_time - last_time))
    
    if [ $diff -ge $MIN_NOTIFICATION_INTERVAL ]; then
        # Actualizar timestamp
        sed -i "/^$key:/d" "$STATE_FILE" 2>/dev/null
        echo "$key:$current_time" >> "$STATE_FILE"
        return 0
    fi
    
    logger -p info -t "network-notify" "Notificación omitida por rate limit ($diff < $MIN_NOTIFICATION_INTERVAL seg)"
    return 1
}

# Escapar caracteres especiales para MarkdownV2
escape_markdown() {
    echo "$1" | sed 's/[_*\[\]()~`>#+=|{}.!-]/\\&/g'
}

# Enviar mensaje a Telegram con formato HTML
send_to_telegram() {
    local message="$1"
    local retries=3
    local success=0
    
    # Validar credenciales
    if [ -z "$TOKEN" ] || [ -z "$CHAT_ID" ]; then
        logger -p err -t "network-notify" "ERROR: Token o Chat ID vacíos"
        return 1
    fi
    
    # Log del mensaje
    logger -p info -t "network-notify" "Enviando: $message"
    
    # Intentar enviar con retries
    for i in $(seq 1 $retries); do
        if curl -s -m "$CURL_TIMEOUT" -X POST "$TELEGRAM_URL" \
            -d chat_id="$CHAT_ID" \
            -d parse_mode="HTML" \
            -d disable_notification="false" \
            --data-urlencode "text=$message" >/dev/null 2>&1; then
            success=1
            logger -p info -t "network-notify" "Mensaje enviado exitosamente"
            break
        else
            logger -p warning -t "network-notify" "Intento $i/$retries falló"
            [ $i -lt $retries ] && sleep 2
        fi
    done
    
    if [ $success -eq 0 ]; then
        logger -p err -t "network-notify" "ERROR: No se pudo enviar mensaje tras $retries intentos"
        return 1
    fi
    
    return 0
}

# Formatear mensaje de conexión/desconexión
format_message() {
    local action="$1"
    local timestamp="$2"
    local interface="$3"
    local device="$4"
    local public_ip="$5"
    local hostname="$6"
    
    # Determinar emoji y texto según acción
    local emoji="ℹ️"
    local status_text="Evento"
    local status_emoji=""
    
    case "$action" in
        connected)
            emoji="✅"
            status_text="Conectado"
            status_emoji="🔗"
            ;;
        disconnected)
            emoji="❌"
            status_text="Desconectado"
            status_emoji="⚠️"
            ;;
        *)
            emoji="❓"
            status_text="Desconocido"
            status_emoji="❔"
            ;;
    esac
    
    # Limpiar nombre de interfaz para hashtag
    local clean_interface=$(echo "$interface" | sed 's/[^a-zA-Z0-9]//g')
    
    # Construir mensaje con formato HTML
    cat <<EOF
<b>$emoji Red $status_text</b>

<b>Router:</b> <code>$hostname</code>
<b>Interfaz:</b> <code>$interface</code>
<b>Dispositivo:</b> <code>$device</code>
<b>IP Pública:</b> <code>$public_ip</code>
<b>Estado:</b> $status_emoji <b>$status_text</b>
<b>Timestamp:</b> <i>$timestamp</i>

<i>#$clean_interface #network_event</i>
EOF
}

# ============================================
# SCRIPT PRINCIPAL
# ============================================

# Log de inicio
logger -p info -t "network-notify" "=== Iniciando notificación de red ==="
logger -p info -t "network-notify" "ACTION=$ACTION, INTERFACE=$INTERFACE, DEVICE=$DEVICE"

# Validar que sea un evento relevante
if [ "$ACTION" != "connected" ] && [ "$ACTION" != "disconnected" ]; then
    logger -p info -t "network-notify" "Acción '$ACTION' no requiere notificación, saliendo"
    exit 0
fi

# Verificar rate limiting
notification_key="${INTERFACE}_${ACTION}"
if ! should_notify "$notification_key"; then
    logger -p info -t "network-notify" "Notificación omitida por rate limit"
    exit 0
fi

# Obtener timestamp
TIMESTAMP=$(date '+%A %d-%b-%Y %T')

# Obtener IP pública (puede tardar, hacer en background si es necesario)
logger -p info -t "network-notify" "Obteniendo IP pública..."
PUBLIC_IP=$(get_public_ip "$DEVICE")

# Formatear y enviar mensaje
MESSAGE=$(format_message "$ACTION" "$TIMESTAMP" "$INTERFACE" "$DEVICE" "$PUBLIC_IP" "$HOSTNAME")

if send_to_telegram "$MESSAGE"; then
    logger -p info -t "network-notify" "✓ Notificación enviada exitosamente"
    
    # Ejecutar script de uptime si existe
else
    logger -p err -t "network-notify" "✗ Error al enviar notificación"
    exit 1
fi

logger -p info -t "network-notify" "=== Notificación completada ==="
exit 0
