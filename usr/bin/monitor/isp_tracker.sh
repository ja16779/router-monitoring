#!/bin/sh
# ISP Tracker - Monitorea rendimiento de ambos ISPs
# Uso: isp_tracker.sh [collect|report|notify|speed]

. /etc/monitor/config.sh 2>/dev/null

DATA_DIR="/etc/monitor/isp_data"
TODAY=$(date +%Y-%m-%d)
HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || echo "Router")

# Crear directorio de datos
mkdir -p "$DATA_DIR"

# Configuración de WANs
WAN1_NAME="Telmex"
WAN1_IFACE="pppoe-wan"
WAN1_GW="200.38.193.226"

WAN2_NAME="Megacable"
WAN2_IFACE="lan5"
WAN2_GW="192.168.100.1"

# Servidor de prueba
TEST_SERVER="8.8.8.8"

# ========== FUNCIONES ==========

# Medir latencia por interfaz
measure_latency() {
    local iface="$1"
    local server="$2"
    local result=$(ping -c 5 -W 2 -I "$iface" "$server" 2>/dev/null | tail -1)

    if echo "$result" | grep -q "min/avg/max"; then
        echo "$result" | awk -F'/' '{print $5}'
    else
        echo "0"
    fi
}

# Medir packet loss por interfaz
measure_loss() {
    local iface="$1"
    local server="$2"
    local result=$(ping -c 10 -W 2 -I "$iface" "$server" 2>/dev/null | grep "packet loss")
    echo "$result" | awk '{print $7}' | tr -d '%'
}

# Verificar si WAN está activa
check_wan_status() {
    local gw="$1"
    ping -c 1 -W 2 "$gw" >/dev/null 2>&1 && echo "UP" || echo "DOWN"
}

# Recolectar datos
collect_data() {
    local timestamp=$(date +%H:%M)

    # WAN1 (Telmex)
    local wan1_status=$(check_wan_status "$WAN1_GW")
    local wan1_lat="0"
    local wan1_loss="0"
    if [ "$wan1_status" = "UP" ]; then
        wan1_lat=$(measure_latency "$WAN1_IFACE" "$TEST_SERVER")
        wan1_loss=$(measure_loss "$WAN1_IFACE" "$TEST_SERVER")
    fi

    # WAN2 (Megacable)
    local wan2_status=$(check_wan_status "$WAN2_GW")
    local wan2_lat="0"
    local wan2_loss="0"
    if [ "$wan2_status" = "UP" ]; then
        wan2_lat=$(measure_latency "$WAN2_IFACE" "$TEST_SERVER")
        wan2_loss=$(measure_loss "$WAN2_IFACE" "$TEST_SERVER")
    fi

    # Guardar: timestamp,wan1_status,wan1_lat,wan1_loss,wan2_status,wan2_lat,wan2_loss
    echo "$timestamp,$wan1_status,$wan1_lat,$wan1_loss,$wan2_status,$wan2_lat,$wan2_loss" >> "$DATA_DIR/$TODAY.csv"

    logger -t "isp_tracker" "$WAN1_NAME:$wan1_status/${wan1_lat}ms $WAN2_NAME:$wan2_status/${wan2_lat}ms"
}

# Calcular estadísticas de una WAN
calc_wan_stats() {
    local file="$DATA_DIR/$TODAY.csv"
    local wan="$1"  # 1 o 2

    if [ ! -f "$file" ]; then
        echo "0,0,0,0,0"
        return
    fi

    if [ "$wan" = "1" ]; then
        # Campos: status=2, lat=3, loss=4
        awk -F',' '
        BEGIN { sum=0; count=0; max=0; min=9999; up=0; total=0 }
        {
            total++
            if ($2 == "UP") {
                up++
                if ($3 > 0) {
                    sum += $3
                    count++
                    if ($3 > max) max = $3
                    if ($3 < min) min = $3
                }
            }
        }
        END {
            if (count > 0) {
                avg = sum / count
                uptime = (up / total) * 100
                printf "%.1f,%.1f,%.1f,%.0f,%d\n", avg, min, max, uptime, count
            } else {
                print "0,0,0,0,0"
            }
        }' "$file"
    else
        # Campos: status=5, lat=6, loss=7
        awk -F',' '
        BEGIN { sum=0; count=0; max=0; min=9999; up=0; total=0 }
        {
            total++
            if ($5 == "UP") {
                up++
                if ($6 > 0) {
                    sum += $6
                    count++
                    if ($6 > max) max = $6
                    if ($6 < min) min = $6
                }
            }
        }
        END {
            if (count > 0) {
                avg = sum / count
                uptime = (up / total) * 100
                printf "%.1f,%.1f,%.1f,%.0f,%d\n", avg, min, max, uptime, count
            } else {
                print "0,0,0,0,0"
            }
        }' "$file"
    fi
}

# Obtener estado actual
get_current_status() {
    local wan1_status=$(check_wan_status "$WAN1_GW")
    local wan2_status=$(check_wan_status "$WAN2_GW")
    echo "$wan1_status,$wan2_status"
}

# Determinar calidad
get_quality() {
    local avg_latency="$1"
    local uptime="$2"

    if [ "$uptime" -lt 90 ] 2>/dev/null; then
        echo "❌ Inestable"
    elif [ "${avg_latency%.*}" -gt 100 ] 2>/dev/null; then
        echo "⚠️ Lento"
    elif [ "${avg_latency%.*}" -gt 50 ] 2>/dev/null; then
        echo "✅ Normal"
    elif [ "${avg_latency%.*}" -gt 0 ] 2>/dev/null; then
        echo "🚀 Excelente"
    else
        echo "❌ Sin datos"
    fi
}

# ========== MAIN ==========
case "$1" in
    collect)
        collect_data
        ;;

    report)
        echo "========================================"
        echo "       ISP Performance Report"
        echo "========================================"
        echo "Router: $HOSTNAME"
        echo "Fecha: $TODAY"
        echo ""

        current=$(get_current_status)
        wan1_now=$(echo "$current" | cut -d',' -f1)
        wan2_now=$(echo "$current" | cut -d',' -f2)

        # WAN1 stats
        wan1_stats=$(calc_wan_stats 1)
        wan1_avg=$(echo "$wan1_stats" | cut -d',' -f1)
        wan1_min=$(echo "$wan1_stats" | cut -d',' -f2)
        wan1_max=$(echo "$wan1_stats" | cut -d',' -f3)
        wan1_uptime=$(echo "$wan1_stats" | cut -d',' -f4)
        wan1_quality=$(get_quality "$wan1_avg" "$wan1_uptime")

        # WAN2 stats
        wan2_stats=$(calc_wan_stats 2)
        wan2_avg=$(echo "$wan2_stats" | cut -d',' -f1)
        wan2_min=$(echo "$wan2_stats" | cut -d',' -f2)
        wan2_max=$(echo "$wan2_stats" | cut -d',' -f3)
        wan2_uptime=$(echo "$wan2_stats" | cut -d',' -f4)
        wan2_quality=$(get_quality "$wan2_avg" "$wan2_uptime")

        echo "=== $WAN1_NAME (WAN) ==="
        echo "Estado: $wan1_now"
        echo "Calidad: $wan1_quality"
        echo "Latencia: ${wan1_avg}ms (min:${wan1_min} max:${wan1_max})"
        echo "Uptime: ${wan1_uptime}%"
        echo ""
        echo "=== $WAN2_NAME (secondwan) ==="
        echo "Estado: $wan2_now"
        echo "Calidad: $wan2_quality"
        echo "Latencia: ${wan2_avg}ms (min:${wan2_min} max:${wan2_max})"
        echo "Uptime: ${wan2_uptime}%"
        echo ""

        samples=$(wc -l < "$DATA_DIR/$TODAY.csv" 2>/dev/null | tr -d ' ')
        echo "Muestras: ${samples:-0}"
        echo "========================================"
        ;;

    notify)
        FECHA=$(date "+%d/%m/%Y %H:%M")

        current=$(get_current_status)
        wan1_now=$(echo "$current" | cut -d',' -f1)
        wan2_now=$(echo "$current" | cut -d',' -f2)

        [ "$wan1_now" = "UP" ] && wan1_icon="✅" || wan1_icon="❌"
        [ "$wan2_now" = "UP" ] && wan2_icon="✅" || wan2_icon="❌"

        # WAN1 stats
        wan1_stats=$(calc_wan_stats 1)
        wan1_avg=$(echo "$wan1_stats" | cut -d',' -f1)
        wan1_min=$(echo "$wan1_stats" | cut -d',' -f2)
        wan1_max=$(echo "$wan1_stats" | cut -d',' -f3)
        wan1_uptime=$(echo "$wan1_stats" | cut -d',' -f4)
        wan1_quality=$(get_quality "$wan1_avg" "$wan1_uptime")

        # WAN2 stats
        wan2_stats=$(calc_wan_stats 2)
        wan2_avg=$(echo "$wan2_stats" | cut -d',' -f1)
        wan2_min=$(echo "$wan2_stats" | cut -d',' -f2)
        wan2_max=$(echo "$wan2_stats" | cut -d',' -f3)
        wan2_uptime=$(echo "$wan2_stats" | cut -d',' -f4)
        wan2_quality=$(get_quality "$wan2_avg" "$wan2_uptime")

        samples=$(wc -l < "$DATA_DIR/$TODAY.csv" 2>/dev/null | tr -d ' ')

        MENSAJE="<b>📊 ISP Tracker</b>
<code>━━━━━━━━━━━━━━━━━━━━</code>
Router: $HOSTNAME | $TODAY

<b>$WAN1_NAME</b> $wan1_icon
├ Estado: $wan1_now | $wan1_quality
├ Latencia: <b>${wan1_avg}ms</b> (${wan1_min}-${wan1_max})
└ Uptime: ${wan1_uptime}%

<b>$WAN2_NAME</b> $wan2_icon
├ Estado: $wan2_now | $wan2_quality
├ Latencia: <b>${wan2_avg}ms</b> (${wan2_min}-${wan2_max})
└ Uptime: ${wan2_uptime}%

Muestras: ${samples:-0}
<code>━━━━━━━━━━━━━━━━━━━━</code>
$FECHA"

        curl -s -X POST --connect-timeout 10 \
            "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${MENSAJE}" \
            -d "parse_mode=HTML" \
            -d "disable_notification=true" >/dev/null 2>&1

        echo "Reporte enviado a Telegram"
        ;;

    *)
        echo "Uso: $0 [collect|report|notify]"
        echo "  collect - Recolectar datos de latencia"
        echo "  report  - Mostrar reporte del día"
        echo "  notify  - Enviar reporte a Telegram"
        ;;
esac
