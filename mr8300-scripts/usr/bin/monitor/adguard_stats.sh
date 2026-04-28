#!/bin/sh
# AdGuard Stats - Resumen de estadisticas de AdGuardHome
# Uso: adguard_stats.sh [-v] [notify]

VERBOSE=""
NOTIFY=""
[ "$1" = "-v" ] && VERBOSE=1
[ "$1" = "notify" ] || [ "$2" = "notify" ] && NOTIFY=1

LOGTAG="adguard-stats"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"

AGH_DIR="/etc/AdGuardHome"
AGH_DATA="$AGH_DIR/data"
AGH_FILTERS="$AGH_DATA/filters"
AGH_CONFIG="$AGH_DIR/config.yaml"

send_telegram() {
    [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && return
    curl -skim 10         --data parse_mode="HTML"         --data chat_id="$TELEGRAM_CHAT_ID"         --data-urlencode "text=$1"         "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

format_size() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        awk "BEGIN {printf \"%.2fGB\", $bytes/1073741824}"
    elif [ "$bytes" -ge 1048576 ]; then
        awk "BEGIN {printf \"%.2fMB\", $bytes/1048576}"
    elif [ "$bytes" -ge 1024 ]; then
        awk "BEGIN {printf \"%.2fKB\", $bytes/1024}"
    else
        echo "${bytes}B"
    fi
}

format_number() {
    echo "$1" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'
}

format_uptime() {
    local secs=$1
    local days=$((secs / 86400))
    local hours=$(((secs % 86400) / 3600))
    local mins=$(((secs % 3600) / 60))
    if [ $days -gt 0 ]; then
        echo "${days}d ${hours}h ${mins}m"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${mins}m"
    else
        echo "${mins}m"
    fi
}

# Verificar que AdGuardHome esta corriendo
AGH_PID=$(pidof AdGuardHome 2>/dev/null || pgrep -x AdGuardHome 2>/dev/null | head -1)
if [ -z "$AGH_PID" ]; then
    AGH_STATUS="DETENIDO"
    AGH_UPTIME="N/A"
    AGH_MEM="N/A"
else
    AGH_STATUS="Activo"
    
    # Calcular uptime usando /proc
    if [ -f "/proc/$AGH_PID/stat" ]; then
        START_JIFFIES=$(cut -d" " -f22 /proc/$AGH_PID/stat)
        SYS_UPTIME=$(cut -d"." -f1 /proc/uptime)
        CLK_TCK=100
        PROC_START_SEC=$((START_JIFFIES / CLK_TCK))
        PROC_UPTIME=$((SYS_UPTIME - PROC_START_SEC))
        AGH_UPTIME=$(format_uptime $PROC_UPTIME)
    else
        AGH_UPTIME="N/A"
    fi

    # Memoria usada
    AGH_MEM_KB=$(awk '/VmRSS/{print $2}' /proc/$AGH_PID/status 2>/dev/null)
    AGH_MEM=$(format_size $((${AGH_MEM_KB:-0} * 1024)))
fi

# Contar reglas de filtros
TOTAL_RULES=0
FILTER_COUNT=0
FILTER_DETAILS=""

if [ -d "$AGH_FILTERS" ]; then
    for filter in "$AGH_FILTERS"/*.txt; do
        [ -f "$filter" ] || continue
        FILTER_COUNT=$((FILTER_COUNT + 1))
        RULES=$(grep -c "^[^#!]" "$filter" 2>/dev/null || echo 0)
        TOTAL_RULES=$((TOTAL_RULES + RULES))

        FNAME=$(basename "$filter" .txt)
        SIZE=$(wc -c < "$filter" 2>/dev/null || echo 0)
        FILTER_DETAILS="${FILTER_DETAILS}  ${FNAME}: $(format_number $RULES) reglas ($(format_size $SIZE))
"
    done
fi

# Obtener upstreams DNS configurados
UPSTREAMS=$(grep -A20 "upstream_dns:" "$AGH_CONFIG" 2>/dev/null | grep "^\s*-" | head -4 | sed 's/.*- /  /' | tr -d '"')

# Espacio usado por AdGuard
AGH_SIZE=$(du -sb "$AGH_DIR" 2>/dev/null | cut -f1)
AGH_SIZE_FMT=$(format_size ${AGH_SIZE:-0})

# Cache info del config
CACHE_SIZE=$(grep "cache_size:" "$AGH_CONFIG" 2>/dev/null | awk '{print $2}')
CACHE_SIZE_FMT=$(format_size ${CACHE_SIZE:-0})

# Rate limit
RATE_LIMIT=$(grep "ratelimit:" "$AGH_CONFIG" 2>/dev/null | head -1 | awk '{print $2}')

# Errores recientes en log
ERRORS_TODAY=$(logread 2>/dev/null | grep -c "AdGuardHome.*\[error\]" || echo 0)

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(uname -n)

# Construir mensaje
STATS_MSG="<b>AdGuard Stats</b>
<pre>
Router: $HOSTNAME
Fecha: $TIMESTAMP

Estado: $AGH_STATUS
Uptime: $AGH_UPTIME
Memoria: $AGH_MEM

Filtros: $FILTER_COUNT listas
Reglas: $(format_number $TOTAL_RULES)
Espacio: $AGH_SIZE_FMT
Cache: $CACHE_SIZE_FMT

Rate limit: ${RATE_LIMIT:-N/A} req/s
Errores hoy: $ERRORS_TODAY
</pre>"

# Verbose output
if [ -n "$VERBOSE" ]; then
    echo "========================================"
    echo "       AdGuardHome Statistics"
    echo "========================================"
    echo ""
    echo "Estado: $AGH_STATUS"
    echo "Uptime: $AGH_UPTIME"
    echo "Memoria: $AGH_MEM"
    echo "PID: ${AGH_PID:-N/A}"
    echo ""
    echo "=== Filtros ($FILTER_COUNT listas) ==="
    echo "$FILTER_DETAILS"
    echo "Total reglas: $(format_number $TOTAL_RULES)"
    echo ""
    echo "=== Configuracion ==="
    echo "Cache size: $CACHE_SIZE_FMT"
    echo "Rate limit: ${RATE_LIMIT:-N/A} req/s"
    echo "Espacio total: $AGH_SIZE_FMT"
    echo ""
    echo "=== DNS Upstreams ==="
    echo "$UPSTREAMS"
    echo ""
    echo "=== Errores recientes ==="
    echo "Errores hoy: $ERRORS_TODAY"
    if [ "$ERRORS_TODAY" -gt 0 ]; then
        echo ""
        logread 2>/dev/null | grep "AdGuardHome.*\[error\]" | tail -5
    fi
fi

# Notificar
if [ -n "$NOTIFY" ]; then
    send_telegram "$STATS_MSG"
    echo "Notificacion enviada"
fi
