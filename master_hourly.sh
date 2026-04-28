#!/bin/sh
# master_hourly.sh - Tareas cada hora
# Cron: 0 * * * * (cada hora)
# Contiene: dns, monitor_seguridad, isp_tracker collect, overlay_check

set -u

INTERVAL=$(date +%s)
STATE_DIR="/tmp/monitor_super_hourly"
LOG_FILE="/var/log/monitor_hourly.log"

mkdir -p "$STATE_DIR"

log_msg() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

run_if_interval() {
    local name=$1
    local interval=$2
    local cmd=$3
    local last_file="$STATE_DIR/monitor_${name}_last"

    [ -f "$last_file" ] && last=$(cat "$last_file" 2>/dev/null || echo 0) || last=0
    elapsed=$((INTERVAL - last))

    if [ "$elapsed" -ge "$interval" ]; then
        log_msg "INFO" "Ejecutando $name"
        if sh -c "$cmd" >> "$LOG_FILE" 2>&1; then
            echo "$INTERVAL" > "$last_file"
            log_msg "INFO" "$name: OK"
        else
            log_msg "ERROR" "$name: Falló (exit: $?)"
        fi
    fi
}

log_msg "INFO" "=== Master Hourly iniciado ==="

# ===== CADA HORA =====
run_if_interval "dns" 3600 "/etc/script/dns.sh"
run_if_interval "monitor_seguridad" 3600 "/usr/bin/monitor/monitor_seguridad.sh"
run_if_interval "isp_tracker_collect" 3600 "/usr/bin/monitor/isp_tracker.sh collect"
run_if_interval "overlay_check" 3600 "/usr/bin/monitor/overlay_check.sh"

log_msg "INFO" "=== Master Hourly completado ==="
