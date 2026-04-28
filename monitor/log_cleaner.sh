#!/bin/sh
# Log Cleaner - Limpia logs antiguos y libera espacio
# Uso: log_cleaner.sh [dias] [-v]

DIAS=${1:-7}
VERBOSE=""
[ "$1" = "-v" ] || [ "$2" = "-v" ] && VERBOSE=1
[ "$1" = "-v" ] && DIAS=7

LOGTAG="log-cleaner"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"

# Directorios y patrones a limpiar
LOG_DIRS="/var/log /tmp/log /tmp/monitor"
PATTERNS="*.log *.log.* *.old *.gz conntrack-names+*"

# Archivos especificos a truncar (no borrar)
TRUNCATE_FILES="/var/log/messages"

# Archivos a preservar (no tocar)
PRESERVE="wtmp lastlog"

TOTAL_FREED=0
FILES_DELETED=0
FILES_TRUNCATED=0

log() {
    [ -n "$VERBOSE" ] && echo "$1"
    logger -t "$LOGTAG" "$1"
}

send_telegram() {
    [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && return
    curl -skim 10 \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

format_size() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}")KB"
    else
        echo "${bytes}B"
    fi
}

is_preserved() {
    local file="$1"
    local base=$(basename "$file")
    for p in $PRESERVE; do
        [ "$base" = "$p" ] && return 0
    done
    return 1
}

# Espacio antes
SPACE_BEFORE=$(df /overlay 2>/dev/null | awk 'NR==2 {print $4}')

log "Iniciando limpieza de logs (archivos > $DIAS dias)"

# Limpiar archivos antiguos
for dir in $LOG_DIRS; do
    [ -d "$dir" ] || continue

    for pattern in $PATTERNS; do
        find "$dir" -maxdepth 2 -name "$pattern" -type f -mtime +$DIAS 2>/dev/null | while read file; do
            is_preserved "$file" && continue

            SIZE=$(stat -c%s "$file" 2>/dev/null || echo 0)
            if rm -f "$file" 2>/dev/null; then
                TOTAL_FREED=$((TOTAL_FREED + SIZE))
                FILES_DELETED=$((FILES_DELETED + 1))
                log "Borrado: $file ($(format_size $SIZE))"
            fi
        done
    done
done

# Truncar archivos grandes que no deben borrarse
for file in $TRUNCATE_FILES; do
    [ -f "$file" ] || continue

    SIZE=$(stat -c%s "$file" 2>/dev/null || echo 0)
    # Truncar si > 10MB
    if [ "$SIZE" -gt 10485760 ]; then
        # Guardar ultimas 1000 lineas
        tail -1000 "$file" > "${file}.tmp" 2>/dev/null
        cat "${file}.tmp" > "$file" 2>/dev/null
        rm -f "${file}.tmp"

        NEW_SIZE=$(stat -c%s "$file" 2>/dev/null || echo 0)
        FREED=$((SIZE - NEW_SIZE))
        TOTAL_FREED=$((TOTAL_FREED + FREED))
        FILES_TRUNCATED=$((FILES_TRUNCATED + 1))
        log "Truncado: $file (liberado $(format_size $FREED))"
    fi
done

# Limpiar cache de AdGuardHome si existe y es grande
AGH_CACHE="/tmp/adguardhome"
if [ -d "$AGH_CACHE" ]; then
    SIZE=$(du -sb "$AGH_CACHE" 2>/dev/null | cut -f1)
    if [ "${SIZE:-0}" -gt 52428800 ]; then  # > 50MB
        rm -rf "$AGH_CACHE"/* 2>/dev/null
        log "Cache AdGuard limpiado ($(format_size $SIZE))"
        TOTAL_FREED=$((TOTAL_FREED + SIZE))
    fi
fi

# Limpiar /tmp antiguos
find /tmp -maxdepth 1 -type f -name "*.tmp" -mtime +1 -delete 2>/dev/null
find /tmp -maxdepth 1 -type f -name "tc_*" -mtime +1 -delete 2>/dev/null

# Espacio despues
SPACE_AFTER=$(df /overlay 2>/dev/null | awk 'NR==2 {print $4}')
SPACE_FREED=$((SPACE_AFTER - SPACE_BEFORE))

# Resumen
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ "$FILES_DELETED" -gt 0 ] || [ "$FILES_TRUNCATED" -gt 0 ]; then
    RESUMEN="Archivos borrados: $FILES_DELETED
Archivos truncados: $FILES_TRUNCATED
Espacio liberado: $(format_size $TOTAL_FREED)"

    log "$RESUMEN"

    send_telegram "<b>🧹 Log Cleaner</b>
<pre>
Router: $(uname -n)
Fecha: $TIMESTAMP
$RESUMEN
</pre>"
fi

# Verbose output
if [ -n "$VERBOSE" ]; then
    echo ""
    echo "=== Resumen ==="
    echo "Archivos borrados: $FILES_DELETED"
    echo "Archivos truncados: $FILES_TRUNCATED"
    echo "Espacio liberado: $(format_size $TOTAL_FREED)"
    echo ""
    echo "=== Espacio actual ==="
    df -h /overlay /tmp 2>/dev/null
fi
