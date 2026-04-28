#!/bin/sh
# master_weekly.sh - Tareas especiales por día/hora
# Cron: 0 3/5/8/9 * * 0/1/3 (ver crontab para múltiples entradas)
# Cada cron ejecuta UNA tarea específica basada en la hora y día

set -u

STATE_DIR="/tmp/monitor_super_weekly"
LOG_FILE="/var/log/monitor_weekly.log"

mkdir -p "$STATE_DIR"

log_msg() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

run_task() {
    local name=$1
    local cmd=$2

    log_msg "INFO" "Ejecutando $name"
    if sh -c "$cmd" >> "$LOG_FILE" 2>&1; then
        log_msg "INFO" "$name: OK"
    else
        log_msg "ERROR" "$name: Falló (exit: $?)"
    fi
}

log_msg "INFO" "=== Master Weekly iniciado ==="

# Detectar día de la semana (0=domingo, 1=lunes, 3=miércoles)
dow=$(date +%w)
hour=$(date +%H)
dom=$(date +%d)  # Día del mes (01-31)

# Ejecutar tarea basada en dow + hour
case "${dow}:${hour}" in
    0:03)
        # Domingo 3am
        run_task "reboot" "/etc/script/reboot.sh"
        ;;
    0:05)
        # Domingo 5am
        run_task "wifi_monitor_all" "/usr/bin/monitor/wifi_monitor_all.sh auto notify"
        ;;
    0:08)
        # Domingo 8am
        run_task "iperf_dual_wan" "sh /etc/script/iperf-dual-wan.sh"
        ;;
    1:08)
        # Lunes 8am
        run_task "reporte_semanal" "/usr/bin/monitor/reporte_semanal.sh"
        ;;
    1:09)
        # Lunes 9am
        run_task "firmware_check" "/usr/bin/monitor/firmware_check.sh"
        ;;
    *:03)
        # Cada 3 días a las 3am (días: 1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31)
        # Cálculo: si (día_del_mes - 1) % 3 == 0, entonces ejecutar
        if [ $((($dom - 1) % 3)) -eq 0 ]; then
            run_task "backup_verify" "/usr/bin/monitor/backup_verify.sh"
        fi
        ;;
    *)
        # Si no coincide con ningún patrón, log y salir
        log_msg "WARN" "No hay tarea para dow=$dow hour=$hour dom=$dom"
        ;;
esac

log_msg "INFO" "=== Master Weekly completado ==="
