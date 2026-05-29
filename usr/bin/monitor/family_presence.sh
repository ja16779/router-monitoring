#!/bin/sh
###############################################################################
# FAMILY PRESENCE MONITOR
# Detecta llegadas/salidas de dispositivos de familia en WiFi
# Envía notificaciones a Telegram con hora CST y duración de ausencia
# Compatible: ash/POSIX sh (OpenWrt)
###############################################################################

. /etc/monitor/config.sh 2>/dev/null

STATE_DIR="/tmp/family_presence"
CONFIG_FILE="/etc/monitor/family_devices.conf"
LOG_FILE="/var/log/family_presence.log"
GRACE_PERIOD=300  # 5 minutos

mkdir -p "$STATE_DIR"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Obtener hora actual (UTC)
get_cst_time() {
    date '+%H:%M'
}

# Formatear duración en horas y minutos
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))

    if [ "$hours" -gt 0 ]; then
        echo "${hours}h ${minutes}min"
    else
        echo "${minutes}min"
    fi
}

# Encontrar IP y MAC de un dispositivo por HOSTNAME
find_device_by_hostname() {
    local hostname=$1
    grep "^[^#]*$" /tmp/dhcp.leases 2>/dev/null | while read -r line; do
        dhcp_mac=$(echo "$line" | awk '{print $2}')
        dhcp_ip=$(echo "$line" | awk '{print $3}')
        dhcp_hostname=$(echo "$line" | awk '{print $4}')

        if [ "$dhcp_hostname" = "$hostname" ]; then
            echo "$dhcp_ip|$dhcp_mac"
            return 0
        fi
    done
}

# Encontrar IP de un dispositivo por MAC
find_device_by_mac() {
    local mac=$1
    grep "^[^#]*$" /tmp/dhcp.leases 2>/dev/null | while read -r line; do
        dhcp_mac=$(echo "$line" | awk '{print $2}')
        dhcp_ip=$(echo "$line" | awk '{print $3}')

        if [ "$(echo "$dhcp_mac" | tr 'A-Z' 'a-z')" = "$(echo "$mac" | tr 'A-Z' 'a-z')" ]; then
            echo "$dhcp_ip|$dhcp_mac"
            return 0
        fi
    done
}

# Verificar si una MAC está activa en WiFi (iw station dump)
is_connected_wifi() {
    local mac=$1
    mac_lower=$(echo "$mac" | tr 'A-Z' 'a-z')

    for iface in phy0-ap0 phy0-ap1 phy0-ap2 phy1-ap0 phy1-ap1; do
        if iw dev "$iface" station dump 2>/dev/null | grep -q "^Station $mac_lower"; then
            return 0
        fi
        if iw dev "$iface" station dump 2>/dev/null | grep -q "^Station $mac"; then
            return 0
        fi
    done
    return 1
}

# Verificar si un dispositivo está vivo (ARP + ping fallback)
is_alive() {
    local ip=$1
    local mac=$2

    # Primero: buscar en tabla ARP
    if ip neigh show | grep -i "$mac" | grep -q "REACHABLE\|STALE\|DELAY\|PROBE"; then
        return 0
    fi

    # Fallback: ping
    ping -c 1 -W 1 "$ip" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        return 0
    fi

    return 1
}

# Enviar notificación de llegada a Telegram
notify_arrival() {
    local name=$1
    local emoji=$2
    local duration=$3
    local cst_time=$(get_cst_time)

    local msg="${emoji} <b>${name} llegó</b>
🕒 ${cst_time}"

    if [ -n "$duration" ] && [ "$duration" != "0min" ]; then
        msg="${msg}
📴 Estuvo fuera: ${duration}"
    fi

    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -H 'Content-Type: application/json' \
        -d "{\"chat_id\":\"${TELEGRAM_CHAT_ID}\",\"text\":\"${msg}\",\"parse_mode\":\"HTML\"}" \
        > /dev/null 2>&1

    log_msg "✅ Alert: $name LLEGÓ (fuera: $duration)"
}

# Enviar notificación de salida a Telegram
notify_departure() {
    local name=$1
    local emoji=$2
    local cst_time=$(get_cst_time)

    local msg="${emoji} <b>${name} salió</b>
🕒 ${cst_time}"

    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -H 'Content-Type: application/json' \
        -d "{\"chat_id\":\"${TELEGRAM_CHAT_ID}\",\"text\":\"${msg}\",\"parse_mode\":\"HTML\"}" \
        > /dev/null 2>&1

    log_msg "✅ Alert: $name SALIÓ"
}

# MAIN
if [ ! -f "$CONFIG_FILE" ]; then
    log_msg "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

NOW=$(date +%s)

# Procesar cada dispositivo en la configuración
grep -v "^#" "$CONFIG_FILE" | grep "|" | while IFS='|' read -r name identifier id_type emoji; do
    # Limpiar espacios
    name=$(echo "$name" | xargs)
    identifier=$(echo "$identifier" | xargs)
    id_type=$(echo "$id_type" | xargs)
    emoji=$(echo "$emoji" | xargs)

    # Generar ID único (lowercase, sin espacios)
    device_id=$(echo "$name" | tr 'A-Z ' 'a-z_')

    # Archivos de estado
    state_file="$STATE_DIR/${device_id}_state"
    lastseen_file="$STATE_DIR/${device_id}_lastseen"
    since_file="$STATE_DIR/${device_id}_since"
    lastmac_file="$STATE_DIR/${device_id}_lastmac"

    # Estado anterior
    prev_state=$(cat "$state_file" 2>/dev/null || echo "unknown")

    # Encontrar IP y MAC actual
    device_info=""
    if [ "$id_type" = "hostname" ]; then
        device_info=$(find_device_by_hostname "$identifier")
    elif [ "$id_type" = "mac" ]; then
        device_info=$(find_device_by_mac "$identifier")
    fi

    if [ -z "$device_info" ]; then
        # Dispositivo no encontrado en DHCP leases
        current_state="away"
    else
        current_ip=$(echo "$device_info" | cut -d'|' -f1)
        current_mac=$(echo "$device_info" | cut -d'|' -f2)

        # Guardar MAC actual para referencia futura
        echo "$current_mac" > "$lastmac_file"

        # Verificar si está conectado
        if is_connected_wifi "$current_mac" || is_alive "$current_ip" "$current_mac"; then
            current_state="home"
            echo "$NOW" > "$lastseen_file"
        else
            # No encontrado en WiFi - revisar grace period
            lastseen=$(cat "$lastseen_file" 2>/dev/null || echo "$NOW")
            diff=$((NOW - lastseen))

            if [ "$diff" -lt "$GRACE_PERIOD" ]; then
                # Dentro del grace period - mantener "home"
                current_state="home"
            else
                # Fuera del grace period - "away"
                current_state="away"
            fi
        fi
    fi

    # Detectar cambio de estado
    if [ "$current_state" != "$prev_state" ]; then
        since=$(cat "$since_file" 2>/dev/null || echo "$NOW")

        if [ "$current_state" = "home" ]; then
            # LLEGADA
            if [ "$prev_state" = "away" ] || [ "$prev_state" = "unknown" ]; then
                # Calcular duración de ausencia
                duration_sec=$((NOW - since))
                if [ "$prev_state" = "away" ]; then
                    duration=$(format_duration "$duration_sec")
                else
                    duration=""
                fi
                notify_arrival "$name" "$emoji" "$duration"
            fi
        elif [ "$current_state" = "away" ]; then
            # SALIDA
            if [ "$prev_state" = "home" ]; then
                notify_departure "$name" "$emoji"
            fi
        fi

        # Guardar nuevo estado y timestamp de cambio
        echo "$current_state" > "$state_file"
        echo "$NOW" > "$since_file"
    fi
done

log_msg "✓ Cycle completed"
