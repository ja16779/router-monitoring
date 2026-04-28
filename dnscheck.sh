#!/bin/bash

# ┌────────────────────────────────────────────┐
# │ CONFIGURACIÓN GENERAL                     │
# └────────────────────────────────────────────┘
DNS_SERVER="1.1.1.1"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"
LOG_FILE="/var/log/dns_root_check.log"
ALERTA=0

# ┌────────────────────────────────────────────┐
# │ FUNCIÓN: Enviar alerta por Telegram        │
# └────────────────────────────────────────────┘
send_alert() {
    local mensaje="$1"
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${mensaje}" \
        -d parse_mode="Markdown"
}

# ┌────────────────────────────────────────────┐
# │ FUNCIÓN: Registrar en log                  │
# └────────────────────────────────────────────┘
log_event() {
    echo "$(date '+%F %T') - $1" >> "$LOG_FILE"
}

# ┌────────────────────────────────────────────┐
# │ FUNCIÓN: Verificar servidores raíz DNS     │
# └────────────────────────────────────────────┘
check_root_servers() {
    local resultado
    resultado=$(dig . NS @"$DNS_SERVER" +short)

    if [[ -z "$resultado" ]]; then
        log_event "ERROR: No se recibió respuesta de servidores raíz"
        send_alert "⚠️ *Fallo en consulta DNS raíz*\nNo se recibió respuesta de @$DNS_SERVER"
        ALERTA=1
    else
        local total=$(echo "$resultado" | wc -l)
        if [[ "$total" -lt 13 ]]; then
            log_event "ADVERTENCIA: Se recibieron solo $total servidores raíz"
            send_alert "⚠️ *Advertencia DNS*\nSolo se recibieron $total servidores raíz desde @$DNS_SERVER"
            ALERTA=1
        else
            log_event "OK: Se recibieron $total servidores raíz correctamente"
        fi
    fi
}

# ┌────────────────────────────────────────────┐
# │ EJECUCIÓN PRINCIPAL                        │
# └────────────────────────────────────────────┘
check_root_servers

if [[ "$ALERTA" -eq 0 ]]; then
    echo "✅ Consulta DNS raíz exitosa. Ver log para detalles."
else
    echo "⚠️ Se detectaron problemas. Revisa el log y Telegram."
fi
