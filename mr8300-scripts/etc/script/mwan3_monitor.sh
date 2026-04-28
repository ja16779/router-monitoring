#!/bin/sh
# Script de monitoreo de interfaces mwan3
# Registra caídas, restablecimientos y tiempo de actividad

LOGTAG="mwan3-monitor"
STATE_FILE="/tmp/mwan3_state.txt"
DOWNTIME_FILE="/tmp/mwan3_downtime.txt"
HISTORY_FILE="/tmp/mwan3_history.log"
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID="716542586"

# Detectar token segun router
case "$(uname -n)" in
    GL-MT6000)
        TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
        ;;
    GL-MT3000*)
        TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
        ;;
esac

# Enviar mensaje a Telegram
send_telegram() {
    local message="$1"

    [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && return

    curl -skim 10 \
        --data disable_notification="false" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$message" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

# Formatear segundos a formato legible
format_duration() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%dh:%02dm:%02ds" "$hours" "$minutes" "$secs"
}

# Guardar timestamp de caída
save_downtime() {
    local iface="$1"
    local timestamp="$(date +%s)"
    grep -v "^${iface}|" "$DOWNTIME_FILE" 2>/dev/null > "${DOWNTIME_FILE}.tmp"
    echo "${iface}|${timestamp}" >> "${DOWNTIME_FILE}.tmp"
    mv "${DOWNTIME_FILE}.tmp" "$DOWNTIME_FILE"
}

# Obtener tiempo desconectado
get_downtime() {
    local iface="$1"
    local down_ts=""
    local now="$(date +%s)"

    down_ts="$(grep "^${iface}|" "$DOWNTIME_FILE" 2>/dev/null | cut -d'|' -f2)"

    if [ -n "$down_ts" ]; then
        local diff=$((now - down_ts))
        format_duration "$diff"
        # Limpiar registro
        grep -v "^${iface}|" "$DOWNTIME_FILE" 2>/dev/null > "${DOWNTIME_FILE}.tmp"
        mv "${DOWNTIME_FILE}.tmp" "$DOWNTIME_FILE"
    else
        echo "N/A"
    fi
}

# Obtener estado actual de interfaces
get_interface_status() {
    mwan3 status 2>/dev/null | grep "interface" | while read line; do
        iface=$(echo "$line" | awk '{print $2}')

        if echo "$line" | grep -q "online"; then
            online_time=$(echo "$line" | grep -oE 'online [0-9]+h:[0-9]+m:[0-9]+s' | sed 's/online //')
            uptime=$(echo "$line" | grep -oE 'uptime [0-9]+h:[0-9]+m:[0-9]+s' | sed 's/uptime //')
            echo "${iface}|online|${online_time}|${uptime}"
        else
            echo "${iface}|offline|0|0"
        fi
    done
}

# Registrar evento en historial
log_event() {
    local iface="$1"
    local event="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    echo "$timestamp | $iface | $event" >> "$HISTORY_FILE"
    logger -t "$LOGTAG" "$iface: $event"
}

# Procesar cambios de estado
check_changes() {
    local current_state="$1"
    local prev_state=""
    local timestamp="$(date '+%A %d-%b-%Y %T')"

    # Leer estado anterior
    [ -f "$STATE_FILE" ] && prev_state="$(cat "$STATE_FILE")"

    # Guardar estado actual
    echo "$current_state" > "$STATE_FILE"

    # Si no hay estado anterior, es primera ejecución
    if [ -z "$prev_state" ]; then
        log_event "SYSTEM" "Monitor iniciado"
        return
    fi

    # Comparar cada interfaz
    echo "$current_state" | while read curr_line; do
        [ -z "$curr_line" ] && continue

        iface="$(echo "$curr_line" | cut -d'|' -f1)"
        curr_status="$(echo "$curr_line" | cut -d'|' -f2)"
        curr_online="$(echo "$curr_line" | cut -d'|' -f3)"

        # Buscar estado anterior de esta interfaz
        prev_line="$(echo "$prev_state" | grep "^${iface}|")"
        prev_status="$(echo "$prev_line" | cut -d'|' -f2)"

        # Detectar cambios
        if [ "$curr_status" != "$prev_status" ]; then
            curr_uptime="$(echo "$curr_line" | cut -d'|' -f4)"
            prev_online="$(echo "$prev_line" | cut -d'|' -f3)"

            if [ "$curr_status" = "online" ]; then
                downtime="$(get_downtime "$iface")"
                log_event "$iface" "RESTABLECIDO (uptime: $curr_uptime, estuvo caido: $downtime)"
                send_telegram "<b>mwan3 - Interfaz Restablecida</b>
<pre>
Router: $(uname -n)
Time: $timestamp
Interfaz: $iface
Estado: ONLINE
Online: $curr_online
Uptime: $curr_uptime
Estuvo caído: $downtime
</pre>"
            else
                save_downtime "$iface"
                log_event "$iface" "CAIDO (estuvo online: $prev_online)"
                send_telegram "<b>mwan3 - Interfaz Caída</b>
<pre>
Router: $(uname -n)
Time: $timestamp
Interfaz: $iface
Estado: OFFLINE
Estuvo online: $prev_online
</pre>"
            fi
        fi
    done
}

# Mostrar resumen actual
show_summary() {
    local timestamp="$(date '+%A %d-%b-%Y %T')"

    echo "=== mwan3 Monitor - $timestamp ==="
    echo ""

    mwan3 status 2>/dev/null | grep "interface" | while read line; do
        iface=$(echo "$line" | awk '{print $2}')

        if echo "$line" | grep -q "online"; then
            online_time=$(echo "$line" | grep -oE 'online [0-9]+h:[0-9]+m:[0-9]+s' | sed 's/online //')
            uptime=$(echo "$line" | grep -oE 'uptime [0-9]+h:[0-9]+m:[0-9]+s' | sed 's/uptime //')
            echo "  $iface: ONLINE (online: $online_time, uptime: $uptime)"
        else
            echo "  $iface: OFFLINE"
        fi
    done

    echo ""

    # Mostrar últimos eventos
    if [ -f "$HISTORY_FILE" ]; then
        echo "=== Últimos eventos ==="
        tail -10 "$HISTORY_FILE"
    fi
}

# Main
case "$1" in
    check)
        # Modo de verificación (para cron)
        current="$(get_interface_status)"
        check_changes "$current"
        ;;
    status)
        # Mostrar resumen
        show_summary
        ;;
    history)
        # Mostrar historial completo
        [ -f "$HISTORY_FILE" ] && cat "$HISTORY_FILE" || echo "Sin historial"
        ;;
    test)
        # Enviar mensaje de prueba
        send_telegram "<b>mwan3 Monitor - Test</b>
<pre>
Router: $(uname -n)
Time: $(date '+%A %d-%b-%Y %T')
Status: Monitoreo activo
</pre>"
        echo "Mensaje de prueba enviado"
        ;;
    *)
        echo "Uso: $0 {check|status|history|test}"
        echo "  check   - Verificar cambios (para cron)"
        echo "  status  - Mostrar resumen actual"
        echo "  history - Mostrar historial de eventos"
        echo "  test    - Enviar mensaje de prueba"
        ;;
esac
