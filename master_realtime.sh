#!/bin/sh
# master_realtime.sh - Monitoreo en tiempo real (crítico)
# Cron: */5 * * * * (cada 5 min)
# Contiene: presencia + monitor_internet/servicios/sistema/wa850/re220/beryl/healthcheck
#           + temp_alert/adguard_health/ddns (distribuidos en múltiples intervalos)
# v3: Fix if vacío en run_if_interval

INTERVAL=$(date +%s)
STATE_DIR="/tmp/monitor_super_realtime"
LOG_FILE="/var/log/monitor_realtime.log"

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
        if eval "$cmd" > /dev/null 2>&1; then
            echo "$INTERVAL" > "$last_file"
            log_msg "INFO" "$name: OK"
        else
            local exit_code=$?
            log_msg "ERROR" "$name: Falló (exit: $exit_code)"
        fi
    fi
}

log_msg "INFO" "=== Master Realtime iniciado ==="

# Post-reboot notification (una vez por boot, no bloquea)
[ ! -f "/tmp/reboot_notified" ] && /usr/bin/monitor/reboot_notify.sh &

# ===== CADA 60 SEGUNDOS =====
# DESHABILITADO 2026-08-14: sistema legado, reemplazado por family_presence.sh (crontab cada minuto)
# run_if_interval "presencia" 60 "/usr/bin/monitor/presencia.sh"

# ===== CADA 300 SEGUNDOS (5 MINUTOS) =====
run_if_interval "auto_restore" 300 "/usr/bin/monitor/auto_restore_detector.sh"
run_if_interval "internet" 300 "/usr/bin/monitor/monitor_internet.sh"
run_if_interval "servicios" 300 "/usr/bin/monitor/monitor_servicios.sh"
run_if_interval "sistema" 300 "/usr/bin/monitor/monitor_sistema.sh"
run_if_interval "wa850" 300 "/usr/bin/monitor/wa850_monitor.sh"
run_if_interval "re220" 300 "/usr/bin/monitor/re220_monitor.sh"
run_if_interval "healthcheck" 300 "/usr/bin/monitor/healthcheck_ping.sh"
run_if_interval "beryl" 300 "/usr/bin/monitor/beryl_monitor.sh"
# DESHABILITADO 2026-07-15 para diagnostico de reinicios diarios ~11:45 AM (ver si connectivity_watchdog era la causa)
# run_if_interval "conn_watchdog" 300 "/usr/bin/monitor/connectivity_watchdog.sh"

# ===== CADA 600 SEGUNDOS (10 MINUTOS) =====
run_if_interval "temp" 600 "/usr/bin/monitor/temp_alert.sh"
run_if_interval "adguard_health" 600 "/usr/bin/monitor/adguard_health.sh"
run_if_interval "ddns_duckdns" 600 "/etc/script/ddns_duckdns.sh"

# ===== CADA 900 SEGUNDOS (15 MINUTOS) =====
run_if_interval "monitor_red" 900 "/usr/bin/monitor/monitor_red.sh"
run_if_interval "dhcp_pool" 900 "/usr/bin/monitor/dhcp_pool_monitor.sh"

# ===== CADA 1800 SEGUNDOS (30 MINUTOS) =====
run_if_interval "usb_monitor" 1800 "/usr/bin/monitor/usb_monitor.sh"

log_msg "INFO" "=== Master Realtime completado ==="
