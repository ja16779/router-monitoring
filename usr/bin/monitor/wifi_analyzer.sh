#!/bin/sh
# WiFi Analyzer - Analiza canales WiFi y cambia automáticamente si es necesario
# Uso: wifi_analyzer.sh [-v] [notify] [auto]
#   -v      Verbose output
#   notify  Enviar reporte a Telegram
#   auto    Cambiar canales automáticamente si hay mejores

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

IFACE_2G="wlan0"
IFACE_5G="wlan1"
RADIO_2G="radio0"
RADIO_5G="radio1"

# Canales recomendados (no solapados)
CHANNELS_2G="1 6 11"
CHANNELS_5G="36 40 44 48 149 153 157 161"

# Umbral mínimo de mejora para cambiar (redes menos)
THRESHOLD=2

# Escanear banda
scan_band() {
    local iface="$1"
    iwinfo "$iface" scan 2>/dev/null
}

# Calcular score de un canal (menor = mejor)
calc_channel_score() {
    local scan_data="$1"
    local channel="$2"

    echo "$scan_data" | awk -v ch="$channel" '
    BEGIN { score = 0; count = 0 }
    /Channel:/ { current_ch = $NF }
    /Signal:/ {
        if (current_ch == ch) {
            count++
            gsub(/-/, "", $2)
            signal = $2
            if (signal < 50) score += 10
            else if (signal < 60) score += 7
            else if (signal < 70) score += 5
            else if (signal < 80) score += 3
            else score += 1
        }
    }
    END { print count ":" score }
    '
}

# Obtener canal actual
get_current_channel() {
    local iface="$1"
    iwinfo "$iface" info 2>/dev/null | grep "Channel:" | awk '{print $4}'
}

# Cambiar canal
change_channel() {
    local radio="$1"
    local new_channel="$2"

    uci set wireless.${radio}.channel="$new_channel"
    uci commit wireless
    wifi reload
    sleep 5
}

# Analizar y obtener mejor canal
find_best_channel() {
    local iface="$1"
    local channels="$2"

    local scan_data=$(scan_band "$iface")
    local best_ch=""
    local best_score=9999
    local best_count=9999

    for ch in $channels; do
        local result=$(calc_channel_score "$scan_data" "$ch")
        local count=$(echo "$result" | cut -d: -f1)
        local score=$(echo "$result" | cut -d: -f2)

        echo "$ch:$count:$score"

        if [ "$score" -lt "$best_score" ]; then
            best_score=$score
            best_count=$count
            best_ch=$ch
        fi
    done > /tmp/wifi_ch_analysis_$$.txt

    echo "$best_ch:$best_count:$best_score"
}

# Analizar banda completa
analyze_band() {
    local iface="$1"
    local radio="$2"
    local channels="$3"
    local band="$4"

    local current=$(get_current_channel "$iface")
    local scan_data=$(scan_band "$iface")
    local total=$(echo "$scan_data" | grep -c "^Cell")

    # Obtener score del canal actual
    local current_result=$(calc_channel_score "$scan_data" "$current")
    local current_count=$(echo "$current_result" | cut -d: -f1)
    local current_score=$(echo "$current_result" | cut -d: -f2)

    # Encontrar mejor canal
    local best_ch=""
    local best_count=9999
    local best_score=9999
    local ch_table=""

    for ch in $channels; do
        local result=$(calc_channel_score "$scan_data" "$ch")
        local count=$(echo "$result" | cut -d: -f1)
        local score=$(echo "$result" | cut -d: -f2)

        ch_table="${ch_table}${ch}:${count}:${score}\n"

        if [ "$score" -lt "$best_score" ]; then
            best_score=$score
            best_count=$count
            best_ch=$ch
        fi
    done

    # Decidir si cambiar
    local action="none"
    local improvement=$((current_score - best_score))

    if [ "$current" != "$best_ch" ] && [ "$improvement" -ge "$THRESHOLD" ]; then
        action="change"
    fi

    echo "BAND:$band"
    echo "IFACE:$iface"
    echo "RADIO:$radio"
    echo "TOTAL:$total"
    echo "CURRENT:$current"
    echo "CURRENT_COUNT:$current_count"
    echo "CURRENT_SCORE:$current_score"
    echo "BEST:$best_ch"
    echo "BEST_COUNT:$best_count"
    echo "BEST_SCORE:$best_score"
    echo "IMPROVEMENT:$improvement"
    echo "ACTION:$action"
    echo "TABLE:$(echo -e "$ch_table" | tr '\n' ';')"
}

# Ejecutar análisis
ANALYSIS_2G=$(analyze_band "$IFACE_2G" "$RADIO_2G" "$CHANNELS_2G" "2.4GHz")
ANALYSIS_5G=$(analyze_band "$IFACE_5G" "$RADIO_5G" "$CHANNELS_5G" "5GHz")

# Parsear resultados
parse_field() {
    echo "$1" | grep "^$2:" | cut -d: -f2-
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

# Auto cambio si está habilitado
if [ -n "$AUTO" ]; then
    if [ "$ACTION_2G" = "change" ]; then
        change_channel "$RADIO_2G" "$BEST_2G"
        CHANGED="${CHANGED}2.4GHz: CH $CURRENT_2G → $BEST_2G\n"
        logger -t "wifi_analyzer" "Auto-cambio 2.4GHz: $CURRENT_2G -> $BEST_2G"
    fi

    if [ "$ACTION_5G" = "change" ]; then
        change_channel "$RADIO_5G" "$BEST_5G"
        CHANGED="${CHANGED}5GHz: CH $CURRENT_5G → $BEST_5G\n"
        logger -t "wifi_analyzer" "Auto-cambio 5GHz: $CURRENT_5G -> $BEST_5G"
    fi
fi

# Generar tabla de canales
make_table() {
    local analysis="$1"
    local channels="$2"
    local best=$(parse_field "$analysis" "BEST")

    local scan_data=$(scan_band $(parse_field "$analysis" "IFACE"))

    for ch in $channels; do
        local count=$(calc_channel_score "$scan_data" "$ch" | cut -d: -f1)
        if [ "$ch" = "$best" ]; then
            echo "  CH $ch: $count redes ⭐"
        else
            echo "  CH $ch: $count redes"
        fi
    done
}

# Verbose output
if [ -n "$VERBOSE" ]; then
    echo "========================================"
    echo "       WiFi Channel Analyzer"
    echo "========================================"
    echo "Router: $HOSTNAME"
    echo ""
    echo "=== 2.4 GHz ($TOTAL_2G redes) ==="
    echo "Actual: CH $CURRENT_2G ($CURRENT_COUNT_2G redes)"
    echo "Mejor:  CH $BEST_2G ($BEST_COUNT_2G redes)"
    echo ""
    make_table "$ANALYSIS_2G" "$CHANNELS_2G"
    echo ""
    if [ "$ACTION_2G" = "change" ]; then
        echo "💡 Recomendado: Cambiar a CH $BEST_2G"
    else
        echo "✅ Canal óptimo"
    fi
    echo ""
    echo "=== 5 GHz ($TOTAL_5G redes) ==="
    echo "Actual: CH $CURRENT_5G ($CURRENT_COUNT_5G redes)"
    echo "Mejor:  CH $BEST_5G ($BEST_COUNT_5G redes)"
    echo ""
    make_table "$ANALYSIS_5G" "$CHANNELS_5G"
    echo ""
    if [ "$ACTION_5G" = "change" ]; then
        echo "💡 Recomendado: Cambiar a CH $BEST_5G"
    else
        echo "✅ Canal óptimo"
    fi

    if [ -n "$CHANGED" ]; then
        echo ""
        echo "=== CAMBIOS APLICADOS ==="
        echo -e "$CHANGED"
    fi
    echo "========================================"
fi

# Telegram
if [ -n "$NOTIFY" ]; then
    # Status 2.4GHz
    if [ "$ACTION_2G" = "change" ]; then
        STATUS_2G="💡 Cambiar a CH $BEST_2G"
    else
        STATUS_2G="✅ Óptimo"
    fi

    # Status 5GHz
    if [ "$ACTION_5G" = "change" ]; then
        STATUS_5G="💡 Cambiar a CH $BEST_5G"
    else
        STATUS_5G="✅ Óptimo"
    fi

    CAMBIOS_MSG=""
    if [ -n "$CHANGED" ]; then
        CAMBIOS_MSG="
<b>🔄 CAMBIOS APLICADOS:</b>
<pre>$(echo -e "$CHANGED")</pre>"
    fi

    MENSAJE="<b>📡 WiFi Analyzer</b>
<code>━━━━━━━━━━━━━━━━━━━━</code>
Router: $HOSTNAME

<b>2.4 GHz</b> ($TOTAL_2G redes detectadas)
📻 Canal actual: <b>$CURRENT_2G</b> ($CURRENT_COUNT_2G redes)
🎯 Canal óptimo: $BEST_2G ($BEST_COUNT_2G redes)
$STATUS_2G

<b>5 GHz</b> ($TOTAL_5G redes detectadas)
📻 Canal actual: <b>$CURRENT_5G</b> ($CURRENT_COUNT_5G redes)
🎯 Canal óptimo: $BEST_5G ($BEST_COUNT_5G redes)
$STATUS_5G
$CAMBIOS_MSG
<code>━━━━━━━━━━━━━━━━━━━━</code>
$FECHA"

    curl -s -X POST --connect-timeout 10 \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${MENSAJE}" \
        -d "parse_mode=HTML" \
        -d "disable_notification=true"

    if [ $? -eq 0 ]; then
        echo "Reporte enviado a Telegram"
    else
        echo "ERROR: Fallo al enviar a Telegram"
        logger -t wifi_analyzer "ERROR: curl fallo al enviar a Telegram"
    fi
fi

logger -t "wifi_analyzer" "Analisis: 2.4G=$CURRENT_2G(best:$BEST_2G) 5G=$CURRENT_5G(best:$BEST_5G) changes=$([[ -n \"$CHANGED\" ]] && echo 'yes' || echo 'no')"
