#!/bin/sh
#############################################
# WiFi Monitor Script v2.0 - GL-MT6000
# Monitorea interfaces WiFi y notifica vía Telegram
#############################################

# ============================================
# CONFIGURACIÓN
# ============================================

# Telegram bot credentials
readonly TOKEN="REDACTED_BOT_TOKEN"
readonly CHAT_ID="716542586"
readonly TELEGRAM_URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# Timeout para requests de Telegram (segundos)
readonly CURL_TIMEOUT=10

# Lista de interfaces a monitorear
IFACES="phy0-ap0 wlan0 wlan0-1 wlan1 wlan1-1"

# Archivo de estado para evitar spam
readonly STATE_FILE="/tmp/wificheck_state"

# Tiempo mínimo entre mensajes del mismo tipo (segundos)
readonly MIN_MESSAGE_INTERVAL=300  # 5 minutos

# ============================================
# FUNCIONES
# ============================================

# Obtener SSID asociado a la interfaz (diferente al MT3000)
get_ssid() {
    case "$1" in
        wlan0)    echo "IOT" ;;
        wlan0-1)  echo "Mega_2.4G_A2DF" ;;
        wlan1)    echo "AXTEL XTREMO" ;;
        wlan1-1)  echo "Mega_5G_A2DF" ;;
        phy0-ap0) echo "AXTEL XTREMO 2G" ;;
        *)        echo "Desconocido" ;;
    esac
}

# Verificar si debe enviarse mensaje (evitar spam)
should_send_message() {
    local iface="$1"
    local current_time=$(date +%s)
    local last_time=0
    
    # Leer último timestamp si existe
    if [ -f "$STATE_FILE" ]; then
        last_time=$(grep "^$iface:" "$STATE_FILE" | cut -d: -f2)
        [ -z "$last_time" ] && last_time=0
    fi
    
    # Calcular diferencia
    local diff=$((current_time - last_time))
    
    if [ $diff -ge $MIN_MESSAGE_INTERVAL ]; then
        # Actualizar timestamp
        sed -i "/^$iface:/d" "$STATE_FILE" 2>/dev/null
        echo "$iface:$current_time" >> "$STATE_FILE"
        return 0
    fi
    
    return 1
}

# Enviar mensaje a Telegram con retry y formato HTML
send_telegram_message() {
    local message="$1"
    local force="${2:-0}"  # 1 para forzar envío sin restricción de tiempo
    local iface="$3"
    local retries=3
    local success=0
    
    # Verificar si debe enviarse el mensaje (a menos que sea forzado)
    if [ "$force" -eq 0 ] && [ -n "$iface" ]; then
        if ! should_send_message "$iface"; then
            logger -p info -t "wificheck" "Mensaje no enviado (demasiado reciente): $message"
            return 0
        fi
    fi
    
    # Intentar enviar con retries (usando HTML parse mode)
    for i in $(seq 1 $retries); do
        if curl -s -m "$CURL_TIMEOUT" -X POST "$TELEGRAM_URL" \
            -d chat_id="$CHAT_ID" \
            -d parse_mode="HTML" \
            --data-urlencode "text=$message" >/dev/null 2>&1; then
            success=1
            logger -p info -t "wificheck" "Mensaje enviado a Telegram: $message"
            break
        else
            logger -p warning -t "wificheck" "Intento $i/$retries falló al enviar mensaje"
            [ $i -lt $retries ] && sleep 2
        fi
    done
    
    if [ $success -eq 0 ]; then
        logger -p err -t "wificheck" "ERROR: No se pudo enviar mensaje tras $retries intentos"
        return 1
    fi
    
    return 0
}

# Verificar si la interfaz existe
interface_exists() {
    local iface="$1"
    ip link show "$iface" >/dev/null 2>&1
}

# Verificar estado del servicio hostapd_cli
check_service() {
    local iface="$1"
    local ssid=$(get_ssid "$iface")
    local hostname=$(uname -n)
    
    # Verificar si la interfaz existe
    if ! interface_exists "$iface"; then
        logger -p warning -t "wificheck" "Interfaz $iface no existe, omitiendo"
        return 1
    fi
    
    # Verificar si el proceso está corriendo (patrón específico para MT6000)
    if pgrep -f "hostapd_cli.*-i $iface" >/dev/null 2>&1; then
        # Servicio corriendo - solo log, no Telegram
        logger -p info -t "wificheck" "$hostname: ✓ $iface activo (SSID: $ssid)"
        return 0
    else
        # Servicio caído - intentar levantar
        logger -p warning -t "wificheck" "$hostname: ✗ $iface caído (SSID: $ssid)"
        
        # Intentar iniciar el servicio (usando hostchange.sh en MT6000)
        if hostapd_cli -a /etc/script/hostchange.sh -i "$iface" -B 2>&1 | logger -p notice -t "wificheck"; then
            local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            local msg="<b>🔄 Servicio WiFi Reiniciado</b>

<b>Router:</b> <code>$hostname</code>
<b>Interfaz:</b> <code>$iface</code>
<b>SSID:</b> <i>$ssid</i>
<b>Estado:</b> ✅ <b>Activo</b>
<b>Hora:</b> $timestamp"
            logger -p notice -t "wificheck" "$hostname: Servicio $iface reiniciado exitosamente"
            send_telegram_message "$msg" 0 "$iface"
            return 0
        else
            local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            local msg="<b>⚠️ ERROR - Servicio WiFi Falló</b>

<b>Router:</b> <code>$hostname</code>
<b>Interfaz:</b> <code>$iface</code>
<b>SSID:</b> <i>$ssid</i>
<b>Estado:</b> ❌ <b>Falló al reiniciar</b>
<b>Acción:</b> <u>Revisar manualmente</u>
<b>Hora:</b> $timestamp

<i>Se requiere intervención manual</i>"
            logger -p err -t "wificheck" "$hostname: ERROR al iniciar servicio $iface"
            send_telegram_message "$msg" 1 "$iface"  # Forzar envío en errores
            return 1
        fi
    fi
}

# Verificar salud general del sistema WiFi
check_wifi_health() {
    local total=0
    local active=0
    local hostname=$(uname -n)
    
    for iface in $IFACES; do
        interface_exists "$iface" || continue
        total=$((total + 1))
        pgrep -f "hostapd_cli.*-i $iface" >/dev/null 2>&1 && active=$((active + 1))
    done
    
    if [ $total -eq 0 ]; then
        logger -p err -t "wificheck" "ERROR: No hay interfaces WiFi disponibles"
        return 1
    fi
    
    local percentage=$((active * 100 / total))
    logger -p info -t "wificheck" "Salud WiFi: $active/$total activos ($percentage%)"
    
    # Alertar si menos del 50% están activos
    if [ $percentage -lt 50 ]; then
        local msg="<b>⚠️ ALERTA - Salud WiFi Degradada</b>

<b>Router:</b> <code>$hostname</code>
<b>Interfaces Activas:</b> $active/$total
<b>Porcentaje:</b> <b>$percentage%</b>

<i>⚠️ Menos del 50% de interfaces están activas</i>
<u>Se recomienda revisar configuración</u>"
        send_telegram_message "$msg" 1 "health_check"
    fi
}

# ============================================
# SCRIPT PRINCIPAL
# ============================================

# Crear archivo de estado si no existe
touch "$STATE_FILE" 2>/dev/null

# Log inicio de ejecución
logger -p info -t "wificheck" "=== Iniciando monitoreo WiFi (MT6000) ==="

# Contador de problemas
error_count=0

# Monitorear cada interfaz
for iface in $IFACES; do
    if ! check_service "$iface"; then
        error_count=$((error_count + 1))
    fi
done

# Verificar salud general si hubo problemas
if [ $error_count -gt 0 ]; then
    logger -p warning -t "wificheck" "Detectados $error_count problemas, verificando salud general"
    check_wifi_health
fi

# Log fin de ejecución
logger -p info -t "wificheck" "=== Monitoreo WiFi completado (errores: $error_count) ==="

exit 0
