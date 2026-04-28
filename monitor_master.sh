#!/bin/sh
# monitor_master.sh - Meta-monitor central
# Ejecuta todas las verificaciones según intervalos
# Una sola entrada cron: */5 * * * *

set -u

INTERVAL=$(date +%s)
LAST_RUN_FILE="/tmp/monitor_master_last"
LOG_FILE="/var/log/monitor_master.log"
STATE_DIR="/tmp/monitor_state"

# Crear directorio de estado
mkdir -p "$STATE_DIR"

# Logging
log_msg() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

# Verificar y ejecutar script según intervalo
check_and_run() {
    local name=$1
    local interval=$2  # segundos
    local cmd=$3
    local last_file="$STATE_DIR/monitor_${name}_last"

    # Leer último timestamp
    if [ -f "$last_file" ]; then
        last=$(cat "$last_file" 2>/dev/null || echo 0)
    else
        last=0
    fi

    # Calcular tiempo transcurrido
    elapsed=$((INTERVAL - last))

    # Si es hora de ejecutar
    if [ "$elapsed" -ge "$interval" ]; then
        log_msg "INFO" "Ejecutando $name (elapsed=${elapsed}s, interval=${interval}s)"

        # Ejecutar y capturar errores
        if sh -c "$cmd" >> "$LOG_FILE" 2>&1; then
            echo "$INTERVAL" > "$last_file"
            log_msg "INFO" "$name: OK"
        else
            local exit_code=$?
            log_msg "ERROR" "$name: Falló (exit code: $exit_code)"
        fi
    fi
}

# Log de inicio
log_msg "INFO" "Meta-monitor iniciado"

# ===== CADA 60 SEGUNDOS (1 MINUTO) =====
check_and_run "presencia" 60 "/usr/bin/monitor/presencia.sh"

# ===== CADA 300 SEGUNDOS (5 MINUTOS) =====
check_and_run "internet" 300 "/usr/bin/monitor/monitor_internet.sh"
check_and_run "servicios" 300 "/usr/bin/monitor/monitor_servicios.sh"
check_and_run "sistema" 300 "/usr/bin/monitor/monitor_sistema.sh"
check_and_run "wa850" 300 "/usr/bin/monitor/wa850_monitor.sh"
check_and_run "new_device" 300 "/usr/bin/monitor/new_device_alert.sh"
check_and_run "re220" 300 "/usr/bin/monitor/re220_monitor.sh"
check_and_run "crowdsec" 300 "/usr/bin/monitor/crowdsec_notify.sh"
check_and_run "healthcheck" 300 "/usr/bin/monitor/healthcheck_ping.sh"
check_and_run "beryl" 300 "/usr/bin/monitor/beryl_monitor.sh"

# ===== CADA 600 SEGUNDOS (10 MINUTOS) =====
check_and_run "temp" 600 "/usr/bin/monitor/temp_alert.sh"
check_and_run "adguard_health" 600 "/usr/bin/monitor/adguard_health.sh"

# ===== CADA 900 SEGUNDOS (15 MINUTOS) =====
check_and_run "red" 900 "/usr/bin/monitor/monitor_red.sh"
check_and_run "dhcp_pool" 900 "/usr/bin/monitor/dhcp_pool_monitor.sh"

# Guardar timestamp de esta ejecución
echo "$INTERVAL" > "$LAST_RUN_FILE"

log_msg "INFO" "Meta-monitor completado"
