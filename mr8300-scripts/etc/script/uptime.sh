#!/bin/sh
#############################################
# MWAN3 Link Uptime Tracker v2.0
# Monitorea tiempo de enlace activo de interfaces MWAN3
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

# Hostname del router
HOSTNAME="$(uci get system.@system[0].hostname 2>/dev/null || echo 'OpenWrt')"

# Archivo de histórico de cambios
readonly HISTORY_FILE="/tmp/mwan3_uptime_history"

# Archivo de estado actual (para detectar cambios)
readonly STATE_FILE="/tmp/mwan3_current_state"

# Total de enlaces esperados (ajusta según tu configuración)
readonly EXPECTED_LINKS=2

# ============================================
# FUNCIONES
# ============================================

# Parsear salida de mwan3 interfaces
parse_mwan3_output() {
    local interfaces_info=""
    local online_count=0
    local offline_count=0
    local total_count=0
    local tracking_issues=0
    
    # Verificar si mwan3 está disponible
    if ! command -v mwan3 >/dev/null 2>&1; then
        logger -p err -t "mwan3-tracker" "ERROR: Comando mwan3 no encontrado"
        return 1
    fi
    
    # Obtener salida de mwan3
    local mwan3_output=$(mwan3 interfaces 2>&1)
    
    # Parsear cada línea de interfaz
    echo "$mwan3_output" | grep "interface.*is" | while IFS= read -r line; do
        # Extraer nombre de interfaz
        local iface=$(echo "$line" | sed -n 's/.*interface \([^ ]*\) is.*/\1/p')
        
        # Verificar si está online u offline
        if echo "$line" | grep -q "is online"; then
            total_count=$((total_count + 1))
            online_count=$((online_count + 1))
            
            # Verificar estado del tracking
            local tracking_status="✅"
            if echo "$line" | grep -q "tracking is active"; then
                tracking_status="🔍"
            elif echo "$line" | grep -q "tracking is"; then
                tracking_status="⚠️"
                tracking_issues=$((tracking_issues + 1))
            fi
            
            # Extraer tiempo online (formato: online XXh:XXm:XXs)
            local online_time=$(echo "$line" | sed -n 's/.*online \([0-9]*h:[0-9]*m:[0-9]*s\).*/\1/p')
            
            # Extraer uptime total (formato: uptime XXh:XXm:XXs)
            local uptime=$(echo "$line" | sed -n 's/.*uptime \([0-9]*h:[0-9]*m:[0-9]*s\).*/\1/p')
            
            # Calcular disponibilidad
            local availability="N/A"
            if [ -n "$online_time" ] && [ -n "$uptime" ]; then
                availability=$(calculate_availability "$online_time" "$uptime")
            fi
            
            # Formatear información
            interfaces_info="${interfaces_info}✅ <b>${iface}</b> ${tracking_status}\n"
            
            if [ -n "$online_time" ]; then
                interfaces_info="${interfaces_info}   └ Tiempo Online: <code>${online_time}</code>\n"
            fi
            
            if [ -n "$uptime" ]; then
                interfaces_info="${interfaces_info}   └ Uptime Total: <code>${uptime}</code>\n"
            fi
            
            if [ "$availability" != "N/A" ]; then
                interfaces_info="${interfaces_info}   └ Disponibilidad: <b>${availability}%</b>\n"
            fi
            
            interfaces_info="${interfaces_info}\n"
            
        elif echo "$line" | grep -q "is offline"; then
            total_count=$((total_count + 1))
            offline_count=$((offline_count + 1))
            
            # Extraer uptime si existe
            local uptime=$(echo "$line" | sed -n 's/.*uptime \([0-9]*h:[0-9]*m:[0-9]*s\).*/\1/p')
            
            interfaces_info="${interfaces_info}❌ <b>${iface}</b>\n"
            interfaces_info="${interfaces_info}   └ Estado: <i>Desconectado</i>\n"
            
            if [ -n "$uptime" ]; then
                interfaces_info="${interfaces_info}   └ Último uptime: <code>${uptime}</code>\n"
            fi
            
            interfaces_info="${interfaces_info}\n"
        fi
        
        # Guardar al archivo temporal
        echo "$interfaces_info" > /tmp/mwan3_parse_temp
        echo "$online_count" > /tmp/mwan3_online_temp
        echo "$offline_count" > /tmp/mwan3_offline_temp
        echo "$total_count" > /tmp/mwan3_total_temp
        echo "$tracking_issues" > /tmp/mwan3_tracking_temp
    done
    
    # Leer resultados de archivos temporales
    interfaces_info=$(cat /tmp/mwan3_parse_temp 2>/dev/null)
    online_count=$(cat /tmp/mwan3_online_temp 2>/dev/null || echo 0)
    offline_count=$(cat /tmp/mwan3_offline_temp 2>/dev/null || echo 0)
    total_count=$(cat /tmp/mwan3_total_temp 2>/dev/null || echo 0)
    tracking_issues=$(cat /tmp/mwan3_tracking_temp 2>/dev/null || echo 0)
    
    # Limpiar archivos temporales
    rm -f /tmp/mwan3_parse_temp /tmp/mwan3_online_temp /tmp/mwan3_offline_temp /tmp/mwan3_total_temp /tmp/mwan3_tracking_temp
    
    logger -p info -t "mwan3-tracker" "Total: $total_count, Online: $online_count, Offline: $offline_count, Tracking issues: $tracking_issues"
    
    # Retornar información
    if [ -n "$interfaces_info" ] && [ "$total_count" -gt 0 ]; then
        echo "$interfaces_info|$online_count|$offline_count|$total_count|$tracking_issues"
        return 0
    else
        logger -p warning -t "mwan3-tracker" "No se encontraron interfaces MWAN3"
        return 1
    fi
}

# Calcular porcentaje de disponibilidad
calculate_availability() {
    local online_time="$1"
    local total_uptime="$2"
    
    # Convertir a segundos
    local online_sec=$(time_to_seconds "$online_time")
    local total_sec=$(time_to_seconds "$total_uptime")
    
    if [ "$total_sec" -eq 0 ]; then
        echo "0"
        return
    fi
    
    # Calcular porcentaje
    local percentage=$((online_sec * 100 / total_sec))
    echo "$percentage"
}

# Convertir formato XXh:XXm:XXs a segundos
time_to_seconds() {
    local time_str="$1"
    
    local hours=$(echo "$time_str" | sed -n 's/\([0-9]*\)h.*/\1/p')
    local minutes=$(echo "$time_str" | sed -n 's/.*:\([0-9]*\)m.*/\1/p')
    local seconds=$(echo "$time_str" | sed -n 's/.*:\([0-9]*\)s/\1/p')
    
    [ -z "$hours" ] && hours=0
    [ -z "$minutes" ] && minutes=0
    [ -z "$seconds" ] && seconds=0
    
    echo $((hours * 3600 + minutes * 60 + seconds))
}

# Registrar cambio de estado
log_state_change() {
    local iface="$1"
    local status="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$timestamp|$iface|$status" >> "$HISTORY_FILE"
    
    # Mantener solo últimas 100 líneas
    if [ -f "$HISTORY_FILE" ]; then
        tail -100 "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
        mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
}

# Formatear mensaje para Telegram
format_message() {
    local interfaces="$1"
    local online="$2"
    local offline="$3"
    local total="$4"
    local tracking_issues="$5"
    local timestamp="$6"
    local hostname="$7"
    
    # Determinar emoji y estado según salud
    local health_emoji="✅"
    local health_text="Óptimo"
    local alert_level="info"
    
    # Lógica específica para 2 enlaces
    if [ "$total" -eq 2 ]; then
        if [ "$online" -eq 2 ]; then
            health_emoji="✅"
            health_text="Óptimo - Ambos enlaces activos"
            alert_level="info"
        elif [ "$online" -eq 1 ]; then
            health_emoji="⚠️"
            health_text="DEGRADADO - 1 enlace caído"
            alert_level="warning"
        else
            health_emoji="❌"
            health_text="CRÍTICO - Sin conectividad"
            alert_level="critical"
        fi
    else
        # Para otro número de enlaces
        if [ "$tracking_issues" -gt 0 ]; then
            health_emoji="⚠️"
            health_text="Con alertas de tracking"
            alert_level="warning"
        fi
        
        if [ "$offline" -gt 0 ]; then
            health_emoji="⚠️"
            health_text="Degradado - $offline enlace(s) caído(s)"
            alert_level="warning"
        fi
        
        if [ "$online" -eq 0 ]; then
            health_emoji="❌"
            health_text="CRÍTICO - Sin conectividad"
            alert_level="critical"
        fi
    fi
    
    # Construir mensaje según nivel de alerta
    local header=""
    if [ "$alert_level" = "critical" ]; then
        header="<b>🚨 ALERTA CRÍTICA - MWAN3</b>"
    elif [ "$alert_level" = "warning" ]; then
        header="<b>⚠️ ALERTA - MWAN3</b>"
    else
        header="<b>📊 Reporte MWAN3 - Uptime de Enlaces</b>"
    fi
    
    # Construir mensaje
    cat <<EOF
$header

<b>Router:</b> <code>$hostname</code>
<b>Estado General:</b> $health_emoji <b>$health_text</b>
<b>Enlaces Activos:</b> $online/$total

<b>Estado de Enlaces:</b>
$interfaces<b>Leyenda:</b>
✅ Online | ❌ Offline
🔍 Tracking activo | ⚠️ Alerta de tracking

<b>Timestamp:</b> <i>$timestamp</i>
EOF
}

# Enviar mensaje a Telegram
send_to_telegram() {
    local message="$1"
    local alert_level="${2:-info}"  # info, warning, critical
    local retries=3
    local success=0
    
    # Validar credenciales
    if [ -z "$TOKEN" ] || [ -z "$CHAT_ID" ]; then
        logger -p err -t "mwan3-tracker" "ERROR: Token o Chat ID vacíos"
        return 1
    fi
    
    # Determinar si deshabilitar notificación sonora
    local disable_notification="false"
    if [ "$alert_level" = "info" ]; then
        disable_notification="true"
    fi
    
    # Intentar enviar con retries
    for i in $(seq 1 $retries); do
        if curl -s -m "$CURL_TIMEOUT" -X POST "$TELEGRAM_URL" \
            -d chat_id="$CHAT_ID" \
            -d parse_mode="HTML" \
            -d disable_notification="$disable_notification" \
            --data-urlencode "text=$message" >/dev/null 2>&1; then
            success=1
            logger -p info -t "mwan3-tracker" "✓ Reporte enviado exitosamente (nivel: $alert_level)"
            break
        else
            logger -p warning -t "mwan3-tracker" "Intento $i/$retries falló"
            [ $i -lt $retries ] && sleep 2
        fi
    done
    
    if [ $success -eq 0 ]; then
        logger -p err -t "mwan3-tracker" "✗ ERROR: No se pudo enviar tras $retries intentos"
        return 1
    fi
    
    return 0
}

# Detectar cambios de estado y enviar alertas
detect_state_changes() {
    local current_state="$1"
    local online_count="$2"
    local offline_count="$3"
    
    # Crear archivo de estado si no existe
    if [ ! -f "$STATE_FILE" ]; then
        echo "$current_state" > "$STATE_FILE"
        logger -p info -t "mwan3-tracker" "Estado inicial guardado"
        return 0
    fi
    
    # Leer estado anterior
    local previous_state=$(cat "$STATE_FILE")
    
    # Comparar estados
    if [ "$current_state" != "$previous_state" ]; then
        logger -p warning -t "mwan3-tracker" "⚠️ Cambio de estado detectado"
        logger -p warning -t "mwan3-tracker" "Anterior: $previous_state"
        logger -p warning -t "mwan3-tracker" "Actual: $current_state"
        
        # Actualizar estado
        echo "$current_state" > "$STATE_FILE"
        
        # Determinar tipo de cambio
        local change_type="unknown"
        local alert_msg=""
        
        # Analizar cambio específico
        if echo "$previous_state" | grep -q "online" && echo "$current_state" | grep -q "offline"; then
            # Un enlace cambió de online a offline
            local failed_link=$(echo "$current_state" | grep "offline" | sed 's/|.*//')
            change_type="link_down"
            alert_msg="<b>🔴 ENLACE CAÍDO</b>

<b>Router:</b> <code>$HOSTNAME</code>
<b>Enlace:</b> <code>$failed_link</code>
<b>Estado:</b> ❌ Desconectado
<b>Enlaces activos:</b> $online_count/$EXPECTED_LINKS

<i>⚠️ Sistema operando en modo degradado</i>"
            
        elif echo "$previous_state" | grep -q "offline" && echo "$current_state" | grep -q "online"; then
            # Un enlace se recuperó
            local recovered_link=$(diff <(echo "$previous_state" | tr '|' '\n' | sort) <(echo "$current_state" | tr '|' '\n' | sort) | grep ">" | sed 's/> //')
            change_type="link_up"
            alert_msg="<b>🟢 ENLACE RECUPERADO</b>

<b>Router:</b> <code>$HOSTNAME</code>
<b>Enlace:</b> <code>$recovered_link</code>
<b>Estado:</b> ✅ Conectado
<b>Enlaces activos:</b> $online_count/$EXPECTED_LINKS

<i>✅ Sistema restaurado a operación normal</i>"
        fi
        
        # Enviar alerta si hay mensaje
        if [ -n "$alert_msg" ]; then
            local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            alert_msg="${alert_msg}

<b>Timestamp:</b> <i>$timestamp</i>"
            
            # Determinar nivel de alerta
            local alert_level="warning"
            [ "$change_type" = "link_up" ] && alert_level="info"
            [ "$online_count" -eq 0 ] && alert_level="critical"
            
            send_to_telegram "$alert_msg" "$alert_level"
        fi
        
        return 1  # Hubo cambio
    fi
    
    return 0  # No hubo cambio
}

# ============================================
# SCRIPT PRINCIPAL
# ============================================

# Log inicio
logger -p info -t "mwan3-tracker" "=== Iniciando tracking de enlaces MWAN3 ==="

# Obtener timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Parsear estado de MWAN3
STATUS_INFO=$(parse_mwan3_output)

if [ $? -ne 0 ] || [ -z "$STATUS_INFO" ]; then
    logger -p err -t "mwan3-tracker" "ERROR: No se pudo obtener información de MWAN3"
    
    # Enviar mensaje de error
    ERROR_MSG="<b>⚠️ Error MWAN3</b>

<b>Router:</b> <code>$HOSTNAME</code>
<b>Error:</b> No se pudo obtener estado de interfaces
<b>Timestamp:</b> <i>$TIMESTAMP</i>

<i>Verificar que MWAN3 esté configurado</i>"
    
    send_to_telegram "$ERROR_MSG"
    exit 1
fi

# Parsear información
INTERFACES=$(echo "$STATUS_INFO" | cut -d'|' -f1)
ONLINE_COUNT=$(echo "$STATUS_INFO" | cut -d'|' -f2)
OFFLINE_COUNT=$(echo "$STATUS_INFO" | cut -d'|' -f3)
TOTAL_COUNT=$(echo "$STATUS_INFO" | cut -d'|' -f4)
TRACKING_ISSUES=$(echo "$STATUS_INFO" | cut -d'|' -f5)

logger -p info -t "mwan3-tracker" "Enlaces: $ONLINE_COUNT/$TOTAL_COUNT activos, Alertas: $TRACKING_ISSUES"

# Crear estado simple para comparación (interfaz|estado)
CURRENT_STATE=""
echo "$INTERFACES" | grep -E "^✅|^❌" | while IFS= read -r line; do
    if echo "$line" | grep -q "^✅"; then
        iface=$(echo "$line" | sed -n 's/✅ <b>\([^<]*\)<\/b>.*/\1/p')
        CURRENT_STATE="${CURRENT_STATE}${iface}|online "
    elif echo "$line" | grep -q "^❌"; then
        iface=$(echo "$line" | sed -n 's/❌ <b>\([^<]*\)<\/b>.*/\1/p')
        CURRENT_STATE="${CURRENT_STATE}${iface}|offline "
    fi
    echo "$CURRENT_STATE" > /tmp/mwan3_current_state_temp
done

CURRENT_STATE=$(cat /tmp/mwan3_current_state_temp 2>/dev/null | tr -d '\n')
rm -f /tmp/mwan3_current_state_temp

logger -p info -t "mwan3-tracker" "Estado actual: $CURRENT_STATE"

# Detectar cambios de estado
detect_state_changes "$CURRENT_STATE" "$ONLINE_COUNT" "$OFFLINE_COUNT"
STATE_CHANGED=$?

# Formatear mensaje
MESSAGE=$(format_message "$INTERFACES" "$ONLINE_COUNT" "$OFFLINE_COUNT" "$TOTAL_COUNT" "$TRACKING_ISSUES" "$TIMESTAMP" "$HOSTNAME")

# Determinar nivel de alerta para el reporte
ALERT_LEVEL="info"
if [ "$ONLINE_COUNT" -eq 0 ]; then
    ALERT_LEVEL="critical"
elif [ "$ONLINE_COUNT" -lt "$EXPECTED_LINKS" ]; then
    ALERT_LEVEL="warning"
fi

# Enviar mensaje (solo si hubo cambio de estado o es reporte programado)
if [ "$STATE_CHANGED" -eq 1 ] || [ "${1:-}" = "force" ]; then
    if send_to_telegram "$MESSAGE" "$ALERT_LEVEL"; then
        logger -p info -t "mwan3-tracker" "=== Tracking completado exitosamente ==="
        exit 0
    else
        logger -p err -t "mwan3-tracker" "=== Tracking completado con errores ==="
        exit 1
    fi
else
    logger -p info -t "mwan3-tracker" "Sin cambios detectados, reporte omitido"
    logger -p info -t "mwan3-tracker" "=== Tracking completado (sin envío) ==="
    exit 0
fi
