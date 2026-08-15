#!/bin/bash

###############################################################################
# FAMILY PRESENCE MONITOR
# Monitorea cuándo miembros de la familia llegan/salen
# Envía notificaciones a Telegram
###############################################################################

# CONFIG
STATE_DIR="/tmp/family_presence"
LOG_FILE="/var/log/family_presence.log"

# DISPOSITIVOS A MONITOREAR
# Formato: MAC|Nombre|Tipo
declare -A FAMILY_DEVICES=(
    ["8a:ed:ab:0f:49:cc"]="Fernando|iPhone"
    ["72:44:dc:ee:74:65"]="Papá|iPhone"
    ["da:a5:7d:4e:71:2d"]="Mamá|Samsung"
)

# TELEGRAM
. /etc/monitor/config.sh 2>/dev/null

mkdir -p "$STATE_DIR"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

send_alert() {
    local PERSON="$1"
    local EVENT="$2"    # "LLEGÓ" o "SALIÓ"
    local EMOJI="$3"    # "👋" o "🚪"

    local MSG="${EMOJI} *${PERSON}* ${EVENT}"
    local TIME=$(date '+%H:%M')
    MSG="${MSG}
Hora: ${TIME} UTC"

    # Enviar a Telegram
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -H 'Content-Type: application/json' \
        -d '{"chat_id":"'"${TELEGRAM_CHAT_ID}"'","text":"'"${MSG}"'","parse_mode":"Markdown"}' \
        > /dev/null 2>&1

    log_msg "✅ Alert: $PERSON $EVENT"
}

# OBTENER CLIENTES CONECTADOS ACTUALMENTE
get_connected_clients() {
    local clients=""

    for iface in phy0-ap0 phy0-ap1 phy0-ap2 phy1-ap0 phy1-ap1; do
        local macs=$(iw dev "$iface" station dump 2>/dev/null | grep "^Station" | awk '{print $2}')
        if [ -n "$macs" ]; then
            for mac in $macs; do
                clients="$clients$mac "
            done
        fi
    done

    echo "$clients" | tr ' ' '\n' | sort -u
}

# VERIFICAR CAMBIOS DE PRESENCIA
check_presence() {
    local current_file="$STATE_DIR/current_devices"
    local previous_file="$STATE_DIR/previous_devices"

    # Obtener dispositivos actuales
    get_connected_clients > "$current_file"

    # Primera ejecución
    if [ ! -f "$previous_file" ]; then
        cp "$current_file" "$previous_file"
        log_msg "🔍 Primer escaneo completado"
        return 0
    fi

    # LLEGADAS: en current pero no en previous
    while read -r mac; do
        if ! grep -q "^${mac}$" "$previous_file" 2>/dev/null; then
            for key in "${!FAMILY_DEVICES[@]}"; do
                if [ "$key" = "$mac" ]; then
                    IFS='|' read -r person device <<< "${FAMILY_DEVICES[$key]}"
                    log_msg "🟢 LLEGADA: $person ($device)"
                    send_alert "$person" "LLEGÓ" "👋"
                    break
                fi
            done
        fi
    done < "$current_file"

    # SALIDAS: en previous pero no en current
    while read -r mac; do
        if ! grep -q "^${mac}$" "$current_file" 2>/dev/null; then
            for key in "${!FAMILY_DEVICES[@]}"; do
                if [ "$key" = "$mac" ]; then
                    IFS='|' read -r person device <<< "${FAMILY_DEVICES[$key]}"
                    log_msg "🔴 SALIDA: $person ($device)"
                    send_alert "$person" "SALIÓ" "🚪"
                    break
                fi
            done
        fi
    done < "$previous_file"

    # Guardar estado actual
    cp "$current_file" "$previous_file"
    log_msg "✓ Ciclo completado"
}

# MAIN
check_presence
