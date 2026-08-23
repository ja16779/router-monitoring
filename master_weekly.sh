#!/bin/sh
# master_weekly.sh - Tareas especiales por dia/hora
# Cron: 0 * * * * (cada hora — el case interno decide cuando actuar; antes era 0 3 * * 0, causaba que 6 de 7 ramas nunca se dispararan)
# v4: Fixed case statement sintaxis

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
        local exit_code=$?
        log_msg "ERROR" "$name: Fallo (exit: $exit_code)"
    fi
}

log_msg "INFO" "=== Master Weekly iniciado ==="

# Detectar dia de la semana (0=domingo, 1=lunes, 3=miercoles)
dow=$(date +%w)
hour=$(date +%H)
dom=$(date +%d)  # Dia del mes (01-31)

# Ejecutar tarea basada en dow + hour
case "${dow}:${hour}" in
    *:03)
        # === LAS 3AM - Mantenimiento pesado ===
        # PRIMERO: Cada 3 dias (1, 4, 7, 10, 13, 16, 19, 22, 25, 28, 31): backup_verify
        if [ $((($dom - 1) % 3)) -eq 0 ]; then
            run_task "backup_verify" "/usr/bin/monitor/backup_verify.sh"
        fi
        # Reboot mensual: manejado exclusivamente por scheduled_reboot.sh (cron independiente)
        # Bloque duplicado removido 2026-07-20 (llamaba a /etc/script/reboot.sh, redundante con scheduled_reboot.sh)
        ;;
    0:05)
        # Domingo 5am - Monitoreo WiFi
        run_task "wifi_monitor_all" "/usr/bin/monitor/wifi_monitor_all.sh auto notify"
        ;;
    *:06)
        # Diario 6am - Verificar e instalar actualizaciones de paquetes
        run_task "pkg_updater" "/usr/bin/monitor/pkg_updater.sh upgrade"
        ;;
    0:08)
        # Domingo 8am - Test de rendimiento dual-WAN (iperf)
        run_task "iperf_dual_wan" "sh /etc/script/iperf-dual-wan.sh"
        ;;
    0:09)
        # Domingo 9am - Speedtest en ambas WANs
        run_task "speedtest_dual_wan" "sh /etc/script/speedtest-dual-wan.sh"
        ;;
    0:10)
        # Domingo 10am - Actualizar internet_detector
        run_task "internet_detector_update" "/usr/bin/monitor/internet_detector_setup.sh --update"
        ;;
    1:08)
        # Lunes 8am - Reporte semanal
        run_task "reporte_semanal" "/usr/bin/monitor/reporte_semanal.sh"
        ;;
    1:09)
        # Lunes 9am - Verificar actualizaciones de firmware
        run_task "firmware_check" "/usr/bin/monitor/firmware_check.sh"
        ;;
    *)
        # Si no coincide con ningun patron, log y salir silenciosamente
        log_msg "DEBUG" "No hay tarea para dow=$dow hour=$hour dom=$dom"
        ;;
esac

log_msg "INFO" "=== Master Weekly completado ==="
