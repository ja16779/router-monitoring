#!/bin/sh
# Bufferbloat Test - Mide latencia idle vs bajo carga y califica A-F
# Uso: bufferbloat_test.sh [-v]
# Requiere: netperf, ping, notificar.sh

. /etc/monitor/config.sh 2>/dev/null

TAG="bufferbloat-test"
NETPERF_HOST="netperf-west.bufferbloat.net"
PING_TARGET="8.8.8.8"
DURATION=15
STREAMS=4
PING_COUNT_IDLE=10
PING_COUNT_LOAD=15
TMPDIR="/tmp/bufferbloat_test.$$"

VERBOSE=""
[ "$1" = "-v" ] && VERBOSE=1

cleanup() {
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR"

log() {
    logger -t "$TAG" "$1"
    [ -n "$VERBOSE" ] && echo "$1"
}

# Extraer promedio de ping
# BusyBox: "round-trip min/avg/max = 10.0/12.3/15.0 ms"
# Standard: "rtt min/avg/max/mdev = 10.0/12.3/15.0/1.2 ms"
parse_ping_avg() {
    awk '/min\/avg\/max/{
        sub(/.*= */,"")
        split($1,a,"/")
        print a[2]
    }'
}

# Calificar bufferbloat segun escala Waveform/DSLReports
get_grade() {
    local extra="$1"
    local extra_x10=$(echo "$extra" | awk '{printf "%d", $1 * 10}')
    if [ "$extra_x10" -lt 50 ]; then
        echo "A+"
    elif [ "$extra_x10" -lt 150 ]; then
        echo "A"
    elif [ "$extra_x10" -lt 300 ]; then
        echo "B"
    elif [ "$extra_x10" -lt 600 ]; then
        echo "C"
    elif [ "$extra_x10" -lt 2000 ]; then
        echo "D"
    else
        echo "F"
    fi
}

# Peor calificacion entre dos
worse_grade() {
    local g1="$1" g2="$2"
    local order="A+ A B C D F"
    local pos1=0 pos2=0 i=0
    for g in $order; do
        i=$((i + 1))
        [ "$g" = "$g1" ] && pos1=$i
        [ "$g" = "$g2" ] && pos2=$i
    done
    if [ "$pos1" -ge "$pos2" ]; then
        echo "$g1"
    else
        echo "$g2"
    fi
}

# Emoji segun calificacion
grade_emoji() {
    case "$1" in
        A+|A) echo "🟢" ;;
        B)    echo "🟡" ;;
        C)    echo "🟠" ;;
        D|F)  echo "🔴" ;;
    esac
}

# Sumar throughput de archivos temporales (Mbps)
sum_throughput() {
    local pattern="$1"
    awk '
        /^[0-9]/ { sum += $1 }
        END { printf "%.1f", sum }
    ' $pattern 2>/dev/null
}

log "Iniciando test de bufferbloat"

# --- Paso 1: Latencia idle ---
log "Midiendo latencia idle..."
IDLE_RESULT=$(ping -c "$PING_COUNT_IDLE" -W 2 "$PING_TARGET" 2>/dev/null)
IDLE_AVG=$(echo "$IDLE_RESULT" | parse_ping_avg)

if [ -z "$IDLE_AVG" ]; then
    log "ERROR: No se pudo medir latencia idle"
    exit 1
fi
log "Latencia idle: ${IDLE_AVG}ms"

# --- Paso 2: Latencia bajo carga de descarga ---
log "Midiendo descarga con carga (netperf TCP_MAERTS, ${DURATION}s, ${STREAMS} streams)..."

i=0
while [ "$i" -lt "$STREAMS" ]; do
    netperf -H "$NETPERF_HOST" -t TCP_MAERTS -l "$DURATION" -P 0 -- -o throughput \
        > "$TMPDIR/tp_dl_$i" 2>/dev/null &
    i=$((i + 1))
done

sleep 2

DL_PING_RESULT=$(ping -c "$PING_COUNT_LOAD" -W 2 "$PING_TARGET" 2>/dev/null)
DL_LOAD_AVG=$(echo "$DL_PING_RESULT" | parse_ping_avg)

wait

DL_THROUGHPUT=$(sum_throughput "$TMPDIR/tp_dl_*")
[ -z "$DL_THROUGHPUT" ] || [ "$DL_THROUGHPUT" = "0.0" ] && DL_THROUGHPUT="N/A"

if [ -z "$DL_LOAD_AVG" ]; then
    log "WARN: No se pudo medir latencia bajo carga de descarga"
    DL_LOAD_AVG="$IDLE_AVG"
fi
log "Latencia descarga: ${DL_LOAD_AVG}ms | Throughput: ${DL_THROUGHPUT} Mbps"

# --- Paso 3: Latencia bajo carga de subida ---
log "Midiendo subida con carga (netperf TCP_STREAM, ${DURATION}s, ${STREAMS} streams)..."

i=0
while [ "$i" -lt "$STREAMS" ]; do
    netperf -H "$NETPERF_HOST" -t TCP_STREAM -l "$DURATION" -P 0 -- -o throughput \
        > "$TMPDIR/tp_ul_$i" 2>/dev/null &
    i=$((i + 1))
done

sleep 2

UL_PING_RESULT=$(ping -c "$PING_COUNT_LOAD" -W 2 "$PING_TARGET" 2>/dev/null)
UL_LOAD_AVG=$(echo "$UL_PING_RESULT" | parse_ping_avg)

wait

UL_THROUGHPUT=$(sum_throughput "$TMPDIR/tp_ul_*")
[ -z "$UL_THROUGHPUT" ] || [ "$UL_THROUGHPUT" = "0.0" ] && UL_THROUGHPUT="N/A"

if [ -z "$UL_LOAD_AVG" ]; then
    log "WARN: No se pudo medir latencia bajo carga de subida"
    UL_LOAD_AVG="$IDLE_AVG"
fi
log "Latencia subida: ${UL_LOAD_AVG}ms | Throughput: ${UL_THROUGHPUT} Mbps"

# --- Paso 4: Calcular bufferbloat ---
DL_EXTRA=$(awk "BEGIN {v=$DL_LOAD_AVG - $IDLE_AVG; if(v<0) v=0; printf \"%.1f\", v}")
UL_EXTRA=$(awk "BEGIN {v=$UL_LOAD_AVG - $IDLE_AVG; if(v<0) v=0; printf \"%.1f\", v}")

DL_GRADE=$(get_grade "$DL_EXTRA")
UL_GRADE=$(get_grade "$UL_EXTRA")
GLOBAL_GRADE=$(worse_grade "$DL_GRADE" "$UL_GRADE")
GLOBAL_EMOJI=$(grade_emoji "$GLOBAL_GRADE")

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || uname -n)

log "Descarga: +${DL_EXTRA}ms ($DL_GRADE) | Subida: +${UL_EXTRA}ms ($UL_GRADE) | Global: $GLOBAL_GRADE"

# --- Paso 5: Construir mensaje ---
DL_SPEED="$DL_THROUGHPUT Mbps"
UL_SPEED="$UL_THROUGHPUT Mbps"
[ "$DL_THROUGHPUT" = "N/A" ] && DL_SPEED="N/A"
[ "$UL_THROUGHPUT" = "N/A" ] && UL_SPEED="N/A"

MENSAJE="📊 <b>Bufferbloat Test</b> — $HOSTNAME
━━━━━━━━━━━━━━━━━━━━
⬇️ Download: $DL_SPEED
⬆️ Upload: $UL_SPEED

🏓 Latencia idle: ${IDLE_AVG} ms
⬇️ Latencia descarga: ${DL_LOAD_AVG} ms (+${DL_EXTRA}ms) — <b>$DL_GRADE</b>
⬆️ Latencia subida: ${UL_LOAD_AVG} ms (+${UL_EXTRA}ms) — <b>$UL_GRADE</b>
${GLOBAL_EMOJI} Calificación global: <b>$GLOBAL_GRADE</b>

🕐 $TIMESTAMP"

# --- Paso 6: Enviar ---
/usr/bin/monitor/notificar.sh "$MENSAJE"
log "Resultado enviado por Telegram"

# Verbose output
if [ -n "$VERBOSE" ]; then
    echo ""
    echo "========================================"
    echo "       Bufferbloat Test Results"
    echo "========================================"
    echo "Download:         $DL_SPEED"
    echo "Upload:           $UL_SPEED"
    echo "Idle latency:     ${IDLE_AVG} ms"
    echo "DL latency:       ${DL_LOAD_AVG} ms (+${DL_EXTRA}ms) $DL_GRADE"
    echo "UL latency:       ${UL_LOAD_AVG} ms (+${UL_EXTRA}ms) $UL_GRADE"
    echo "Global grade:     $GLOBAL_GRADE"
    echo "========================================"
fi
