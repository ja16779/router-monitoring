#!/bin/sh
# master_daily.sh - Tareas diarias
# Cron: 0 3 * * * (cada día a las 3am)
# Contiene: contrack, mac_report, reporte_medianoche, config_sync, speedtest-dual-wan,
#           bufferbloat_test, mwan3_test, wifi_channel_monitor, wan_quality_report,
#           reporte_diario, log_cleaner, upgrade_paquetes, banip_auto_update

set -u

STATE_DIR="/tmp/monitor_super_daily"
LOG_FILE="/var/log/monitor_daily.log"

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

log_msg "INFO" "=== Master Daily iniciado ==="

# ===== TAREAS DIVIDIDAS POR HORA =====
# Cron: 0 0,2,3,4,5,7,8,20 * * * (ejecuta en estas 8 horas)
hour=$(date +%H)
minute=$(date +%M)

case $hour in
    0)
        # MEDIANOCHE
        run_task "contrack" "/etc/script/contrack.sh"
        run_task "mac_report" "/usr/bin/monitor/mac_report.sh"
        run_task "reporte_medianoche" "/usr/bin/monitor/reporte_medianoche.sh"
        run_task "mega" "/etc/script/mega.sh && rm /tmp/dhcpmasq.log"
        # Minuto 5
        if [ "$minute" -eq 5 ]; then
            run_task "reporte_leases" "/usr/bin/monitor/reporte_leases.sh"
        fi
        # Minuto 10
        if [ "$minute" -eq 10 ]; then
            run_task "reporte_beryl_wifi" "/usr/bin/monitor/reporte_beryl_wifi.sh"
        fi
        ;;
    2)
        # 02:00 AM
        run_task "speedtest_dual_wan" "/etc/script/speedtest-dual-wan.sh"
        run_task "config_sync" "/usr/bin/monitor/config_sync.sh"
        run_task "upgrade_paquetes" "/usr/bin/monitor/upgrade_paquetes.sh"
        ;;
    3)
        # 03:00 AM
        run_task "log_cleaner" "/usr/bin/monitor/log_cleaner.sh"
        run_task "wifi_channel_monitor" "/usr/bin/monitor/wifi_channel_monitor.sh"
        run_task "banip_auto_update" "/usr/bin/monitor/banip_auto_update.sh"
        ;;
    4)
        # 04:00 AM
        run_task "bufferbloat_test" "/usr/bin/monitor/bufferbloat_test.sh"
        ;;
    5)
        # 05:00 AM
        run_task "mwan3_test" "/usr/bin/monitor/mwan3_test.sh"
        ;;
    7)
        # 07:00 AM
        run_task "reporte_diario" "/usr/bin/monitor/reporte_diario.sh"
        run_task "wan_quality_report" "/usr/bin/monitor/wan_quality_report.sh"
        ;;
    8)
        # 08:00 AM
        run_task "banip_stats" "/usr/bin/monitor/banip_stats.sh"
        ;;
    20)
        # 20:00 (8 PM)
        run_task "isp_tracker_notify" "/usr/bin/monitor/isp_tracker.sh notify"
        ;;
esac

log_msg "INFO" "=== Master Daily completado ==="
