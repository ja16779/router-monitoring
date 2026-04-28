#!/bin/sh
# Script de monitoreo de colas de trafico (tc qdisc)
# Detecta congestion basandose en drops y requeues

LOGTAG="tc-monitor"
INTERFACE="pppoe-wan"
STATE_FILE="/tmp/tc_${INTERFACE}_prev.txt"

# Configuracion Telegram
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID="716542586"

# Detectar token segun router
case "$(uname -n)" in
    GL-MT6000)    TELEGRAM_TOKEN="REDACTED_BOT_TOKEN" ;;
    GL-MT3000*)   TELEGRAM_TOKEN="REDACTED_BOT_TOKEN" ;;
esac

# Enviar alerta a Telegram
send_alert() {
    local message="$1"

    [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && return

    curl -skim 10 \
        --data disable_notification="false" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$message" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

# Sanitizar valor numerico
sanitize_num() {
    local val="$1"
    case "$val" in
        ''|*[!0-9]*) echo 0 ;;
        *) echo "$val" ;;
    esac
}

# Obtener estadisticas actuales
get_current_stats() {
    tc -s qdisc show dev "$INTERFACE" 2>/dev/null | grep -A1 "qdisc fq_codel"
}

# Extraer valor de una linea
extract_value() {
    local text="$1"
    local pattern="$2"
    echo "$text" | sed -n "s/.*${pattern} \([0-9]*\).*/\1/p"
}

# Procesar estadisticas
process_stats() {
    local current="$1"
    local prev="$2"
    local parent=""
    local alert_sent=0

    # Guardar en archivo temporal para evitar subshell
    echo "$current" > /tmp/tc_current_$$

    while read line; do
        if echo "$line" | grep -q "qdisc fq_codel"; then
            parent="$(echo "$line" | sed -n 's/.*parent \([^ ]*\).*/\1/p')"
        fi

        if echo "$line" | grep -q "Sent"; then
            drops="$(sanitize_num "$(extract_value "$line" "dropped")")"
            requeues="$(sanitize_num "$(extract_value "$line" "requeues")")"

            # Obtener valores previos
            prev_line="$(echo "$prev" | grep -A1 "parent $parent" | grep "Sent")"
            prev_drops="$(sanitize_num "$(extract_value "$prev_line" "dropped")")"
            prev_requeues="$(sanitize_num "$(extract_value "$prev_line" "requeues")")"

            # Calcular diferencias
            diff_drops=$((drops - prev_drops))
            diff_requeues=$((requeues - prev_requeues))

            # Detectar congestion
            if [ "$diff_drops" -gt 0 ] || [ "$diff_requeues" -gt 0 ]; then
                logger -t "$LOGTAG" "Congestion en $INTERFACE cola $parent (Drops: +$diff_drops, Requeues: +$diff_requeues)"

                send_alert "<b>Congestion de Red</b>
<pre>
Router: $(uname -n)
Interfaz: $INTERFACE
Cola: $parent
Drops: +$diff_drops (total: $drops)
Requeues: +$diff_requeues (total: $requeues)
</pre>"
                alert_sent=1
            fi
        fi
    done < /tmp/tc_current_$$

    rm -f /tmp/tc_current_$$
    return $alert_sent
}

# Main
current="$(get_current_stats)"

# Primera ejecucion: solo guardar estado
if [ ! -f "$STATE_FILE" ]; then
    echo "$current" > "$STATE_FILE"
    logger -t "$LOGTAG" "Inicializado monitoreo de colas en $INTERFACE"
    exit 0
fi

prev="$(cat "$STATE_FILE")"

# Procesar y detectar congestion
process_stats "$current" "$prev"

# Guardar estado actual
echo "$current" > "$STATE_FILE"
