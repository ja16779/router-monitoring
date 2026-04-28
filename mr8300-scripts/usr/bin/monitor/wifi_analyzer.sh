#!/bin/sh
# WiFi Analyzer - Analiza canales WiFi y recomienda el mejor canal
# Uso: wifi_analyzer.sh [-v] [notify] [auto]
#   -v      Verbose output
#   notify  Enviar reporte a Telegram
#   auto    Cambiar canales automáticamente si hay mejores
# Compatible: OpenWrt 24.10 (wlan0/wlan1) y 25.12 (phy0-ap0/phy1-ap0)

. /etc/monitor/config.sh 2>/dev/null

VERBOSE=""
NOTIFY=""
AUTO=""

for arg in "$@"; do
    case "$arg" in
        -v) VERBOSE=1 ;;
        notify) NOTIFY=1 ;;
        auto) AUTO=1 ;;
    esac
done

RADIO_2G="radio0"
RADIO_5G="radio1"

# Canales recomendados (no solapados)
CHANNELS_2G="1 6 11"
CHANNELS_5G="36 40 44 48 149 153 157 161"

# Umbral mínimo de mejora (puntos de score) para cambiar canal
THRESHOLD=2

# Detectar interfaz activa para un radio
# Compatible con nomenclatura 24.10 (wlanN) y 25.12 (phyN-apY / GL.iNet)
get_radio_iface() {
    local radio_num="${1#radio}"
    # Verificar wlanN: el output debe empezar con el nombre de interfaz
    # (iwinfo wlanN sale con exit 0 aunque no exista, mostrando solo el uso)
    if iwinfo "wlan${radio_num}" info 2>/dev/null | grep -q "^wlan${radio_num}"; then
        echo "wlan${radio_num}"
        return
    fi
    # Buscar phyN-apY (25.12 con GL.iNet naming, ej. Flint-2 GL-MT6000)
    iwinfo 2>/dev/null | awk -v p="phy${radio_num}-" '$1 ~ p {print $1; exit}'
}

IFACE_2G=$(get_radio_iface "$RADIO_2G")
IFACE_5G=$(get_radio_iface "$RADIO_5G")

if [ -z "$IFACE_2G" ] || [ -z "$IFACE_5G" ]; then
    logger -t "wifi_analyzer" "ERROR: interfaces no detectadas (2G='$IFACE_2G' 5G='$IFACE_5G')"
    exit 1
fi

# Escanear banda
scan_band() {
    local iface="$1"
    iwinfo "$iface" scan 2>/dev/null
}

# Obtener canal actual de una interfaz
get_current_channel() {
    local iface="$1"
    iwinfo "$iface" info 2>/dev/null | awk '
        /Channel:/ {
            for (i=1; i<=NF; i++) {
                if ($i == "Channel:") { v = $(i+1)+0; if (v > 0) { print v; exit } }
            }
        }'
}

# Calcular score de interferencia de un canal (menor = mejor)
# Busca "Channel: N" con búsqueda explícita de campo para evitar
# falsos positivos en "Channel Width:", "Primary Channel:", etc.
calc_channel_score() {
    local scan_data="$1"
    local channel="$2"

    printf '%s\n' "$scan_data" | awk -v ch="$channel" '
    BEGIN { score = 0; count = 0; current_ch = -1 }
    /Channel:/ {
        for (i = 1; i <= NF; i++) {
            if ($i == "Channel:") {
                v = $(i+1) + 0
                if (v > 0) { current_ch = v; break }
            }
        }
    }
    /Signal:/ {
        if (current_ch == ch) {
            count++
            sig = $2; gsub(/-/, "", sig); sig = sig + 0
            if      (sig < 50) score += 10
            else if (sig < 60) score += 7
            else if (sig < 70) score += 5
            else if (sig < 80) score += 3
            else               score += 1
        }
    }
    END { print count ":" score }
    '
}

# Cambiar canal (solo en modo auto)
change_channel() {
    local radio="$1"
    local new_channel="$2"
    uci set "wireless.${radio}.channel=${new_channel}"
    uci commit wireless
    wifi reload
    sleep 5
}

# Analizar una banda completa y emitir resultados en formato KEY:VALUE
analyze_band() {
    local iface="$1"
    local radio="$2"
    local channels="$3"
    local band="$4"

    local current scan_data total
    current=$(get_current_channel "$iface")
    scan_data=$(scan_band "$iface")
    total=$(printf '%s\n' "$scan_data" | grep -c "^Cell")

    local cur_result cur_count cur_score
    cur_result=$(calc_channel_score "$scan_data" "$current")
    cur_count=$(printf '%s' "$cur_result" | cut -d: -f1)
    cur_score=$(printf '%s' "$cur_result" | cut -d: -f2)

    local best_ch="" best_count=9999 best_score=9999
    for ch in $channels; do
        local res count score
        res=$(calc_channel_score "$scan_data" "$ch")
        count=$(printf '%s' "$res" | cut -d: -f1)
        score=$(printf '%s' "$res" | cut -d: -f2)
        if [ "${score:-9999}" -lt "$best_score" ]; then
            best_score=$score; best_count=$count; best_ch=$ch
        fi
    done

    local action="none"
    local improvement=$((cur_score - best_score))
    if [ "$current" != "$best_ch" ] && [ "$improvement" -ge "$THRESHOLD" ]; then
        action="change"
    fi

    printf 'BAND:%s\n'          "$band"
    printf 'IFACE:%s\n'         "$iface"
    printf 'RADIO:%s\n'         "$radio"
    printf 'TOTAL:%s\n'         "$total"
    printf 'CURRENT:%s\n'       "$current"
    printf 'CURRENT_COUNT:%s\n' "$cur_count"
    printf 'CURRENT_SCORE:%s\n' "$cur_score"
    printf 'BEST:%s\n'          "$best_ch"
    printf 'BEST_COUNT:%s\n'    "$best_count"
    printf 'BEST_SCORE:%s\n'    "$best_score"
    printf 'IMPROVEMENT:%s\n'   "$improvement"
    printf 'ACTION:%s\n'        "$action"
}

# Ejecutar análisis
ANALYSIS_2G=$(analyze_band "$IFACE_2G" "$RADIO_2G" "$CHANNELS_2G" "2.4GHz")
ANALYSIS_5G=$(analyze_band "$IFACE_5G" "$RADIO_5G" "$CHANNELS_5G" "5GHz")

# Parsear un campo del resultado
parse_field() {
    printf '%s\n' "$1" | grep "^$2:" | cut -d: -f2-
}

CURRENT_2G=$(parse_field "$ANALYSIS_2G" "CURRENT")
BEST_2G=$(parse_field "$ANALYSIS_2G" "BEST")
TOTAL_2G=$(parse_field "$ANALYSIS_2G" "TOTAL")
ACTION_2G=$(parse_field "$ANALYSIS_2G" "ACTION")
BEST_COUNT_2G=$(parse_field "$ANALYSIS_2G" "BEST_COUNT")
CURRENT_COUNT_2G=$(parse_field "$ANALYSIS_2G" "CURRENT_COUNT")

CURRENT_5G=$(parse_field "$ANALYSIS_5G" "CURRENT")
BEST_5G=$(parse_field "$ANALYSIS_5G" "BEST")
TOTAL_5G=$(parse_field "$ANALYSIS_5G" "TOTAL")
ACTION_5G=$(parse_field "$ANALYSIS_5G" "ACTION")
BEST_COUNT_5G=$(parse_field "$ANALYSIS_5G" "BEST_COUNT")
CURRENT_COUNT_5G=$(parse_field "$ANALYSIS_5G" "CURRENT_COUNT")

CHANGED=""
FECHA=$(date "+%d/%m/%Y %H:%M")
HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || uname -n)

# Auto cambio
if [ -n "$AUTO" ]; then
    if [ "$ACTION_2G" = "change" ]; then
        change_channel "$RADIO_2G" "$BEST_2G"
        CHANGED="${CHANGED}2.4GHz: CH ${CURRENT_2G} -> ${BEST_2G}
"
        logger -t "wifi_analyzer" "Auto-cambio 2.4GHz: $CURRENT_2G -> $BEST_2G"
    fi
    if [ "$ACTION_5G" = "change" ]; then
        change_channel "$RADIO_5G" "$BEST_5G"
        CHANGED="${CHANGED}5GHz: CH ${CURRENT_5G} -> ${BEST_5G}
"
        logger -t "wifi_analyzer" "Auto-cambio 5GHz: $CURRENT_5G -> $BEST_5G"
    fi
fi

# Tabla de canales para verbose — marca canal actual y el mejor
make_table() {
    local analysis="$1"
    local channels="$2"
    local best current iface scan_data
    best=$(parse_field "$analysis" "BEST")
    current=$(parse_field "$analysis" "CURRENT")
    iface=$(parse_field "$analysis" "IFACE")
    scan_data=$(scan_band "$iface")

    for ch in $channels; do
        local count suffix
        count=$(calc_channel_score "$scan_data" "$ch" | cut -d: -f1)
        suffix=""
        [ "$ch" = "$best" ]    && suffix="${suffix}  <<< menor interferencia"
        [ "$ch" = "$current" ] && suffix="${suffix}  [actual]"
        printf '  CH %-4s %s redes%s\n' "$ch" "$count" "$suffix"
    done
}

# Mensaje de estado según resultado del análisis
status_msg() {
    local action="$1" current="$2" best="$3" best_count="$4"
    if [ "$action" = "change" ]; then
        printf 'Recomendado: cambiar a CH %s (%s redes)' "$best" "$best_count"
    elif [ "$current" = "$best" ]; then
        printf 'Canal actual es el optimo (CH %s)' "$current"
    else
        printf 'Sin diferencia significativa  (mejor libre: CH %s)' "$best"
    fi
}

# Verbose output
if [ -n "$VERBOSE" ]; then
    printf '========================================\n'
    printf '       WiFi Channel Analyzer\n'
    printf '========================================\n'
    printf 'Router : %s\n' "$HOSTNAME"
    printf 'Ifaces : 2G=%s  5G=%s\n' "$IFACE_2G" "$IFACE_5G"
    printf '\n=== 2.4 GHz (%s redes) ===\n' "$TOTAL_2G"
    printf 'Actual : CH %s (%s redes)\n' "$CURRENT_2G" "$CURRENT_COUNT_2G"
    printf '\n'
    make_table "$ANALYSIS_2G" "$CHANNELS_2G"
    printf '\n'
    printf '%s\n' "$(status_msg "$ACTION_2G" "$CURRENT_2G" "$BEST_2G" "$BEST_COUNT_2G")"
    printf '\n=== 5 GHz (%s redes) ===\n' "$TOTAL_5G"
    printf 'Actual : CH %s (%s redes)\n' "$CURRENT_5G" "$CURRENT_COUNT_5G"
    printf '\n'
    make_table "$ANALYSIS_5G" "$CHANNELS_5G"
    printf '\n'
    printf '%s\n' "$(status_msg "$ACTION_5G" "$CURRENT_5G" "$BEST_5G" "$BEST_COUNT_5G")"
    [ -n "$CHANGED" ] && printf '\n=== CAMBIOS APLICADOS ===\n%s\n' "$CHANGED"
    printf '========================================\n'
fi

# Telegram notify
if [ -n "$NOTIFY" ]; then
    STATUS_2G=$(status_msg "$ACTION_2G" "$CURRENT_2G" "$BEST_2G" "$BEST_COUNT_2G")
    STATUS_5G=$(status_msg "$ACTION_5G" "$CURRENT_5G" "$BEST_5G" "$BEST_COUNT_5G")

    CAMBIOS_MSG=""
    [ -n "$CHANGED" ] && CAMBIOS_MSG="
<b>Cambios aplicados:</b>
<pre>${CHANGED}</pre>"

    MENSAJE="<b>WiFi Analyzer</b>
<code>--------------------</code>
Router: $HOSTNAME

<b>2.4 GHz</b> ($TOTAL_2G redes)
Canal actual: <b>$CURRENT_2G</b> ($CURRENT_COUNT_2G redes)
Canal optimo: <b>$BEST_2G</b> ($BEST_COUNT_2G redes)
$STATUS_2G

<b>5 GHz</b> ($TOTAL_5G redes)
Canal actual: <b>$CURRENT_5G</b> ($CURRENT_COUNT_5G redes)
Canal optimo: <b>$BEST_5G</b> ($BEST_COUNT_5G redes)
$STATUS_5G
$CAMBIOS_MSG
<code>--------------------</code>
$FECHA"

    RESPUESTA=$(curl -s -X POST --connect-timeout 10 \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${MENSAJE}" \
        -d "parse_mode=HTML" \
        -d "disable_notification=true" 2>&1)

    if printf '%s' "$RESPUESTA" | grep -q '"ok":true'; then
        echo "Reporte enviado a Telegram"
        logger -t "wifi_analyzer" "Telegram OK"
    else
        echo "ERROR: Fallo al enviar a Telegram"
        logger -t "wifi_analyzer" "ERROR Telegram: $RESPUESTA"
    fi
fi

logger -t "wifi_analyzer" "2G=$CURRENT_2G(best:$BEST_2G,if:$IFACE_2G) 5G=$CURRENT_5G(best:$BEST_5G,if:$IFACE_5G) changes=$([ -n "$CHANGED" ] && echo yes || echo no)"
