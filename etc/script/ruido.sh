#!/bin/sh
# Script de auditoria de ruido WiFi
# Monitorea SNR (Signal-to-Noise Ratio) de clientes conectados

LOGTAG="wifi_audit"
SNR_THRESHOLD=20

# Configuracion Telegram (opcional)
TELEGRAM_ENABLED="true"
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID="716542586"

# Detectar token segun router
case "$(uname -n)" in
    GL-MT6000)    TELEGRAM_TOKEN="REDACTED_BOT_TOKEN" ;;
    GL-MT3000*)   TELEGRAM_TOKEN="REDACTED_BOT_TOKEN" ;;
esac

# Enviar alerta a Telegram
send_alert() {
    local message="$1"

    [ "$TELEGRAM_ENABLED" != "true" ] && return
    [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && return

    curl -skim 10 \
        --data disable_notification="false" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$message" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

# Obtener lista de interfaces WiFi activas
get_interfaces() {
    iwinfo | awk '/ESSID/{print $1}'
}

# Procesar cada interfaz
audit_interface() {
    local iface="$1"

    # Procesar cada cliente conectado
    # Formato: MAC  RSSI dBm / NOISE dBm (SNR X)  time ago
    iwinfo "$iface" assoclist | grep -E '^[0-9A-Fa-f:]{17}' | while read line; do
        mac="$(echo "$line" | awk '{print $1}')"
        rssi="$(echo "$line" | awk '{print $2}')"
        noise="$(echo "$line" | awk '{print $5}')"
        snr="$(echo "$line" | sed -n 's/.*(SNR \([0-9]*\)).*/\1/p')"

        # Validar SNR
        if ! echo "$snr" | grep -Eq '^[0-9]+$'; then
            logger -t "$LOGTAG" "ERROR: SNR invalido para $mac en $iface"
            continue
        fi

        # Log normal
        logger -t "$LOGTAG" "iface=$iface mac=$mac RSSI=${rssi}dBm NOISE=${noise}dBm SNR=${snr}dB"

        # Alerta si SNR bajo
        if [ "$snr" -lt "$SNR_THRESHOLD" ]; then
            logger -t "$LOGTAG" "ALERTA: Cliente $mac en $iface con SNR bajo (${snr}dB)"
            send_alert "<b>ALERTA WiFi - SNR Bajo</b>
<pre>
Router: $(uname -n)
Cliente: $mac
Interfaz: $iface
RSSI: ${rssi} dBm
Noise: ${noise} dBm
SNR: ${snr} dB
</pre>"
        fi
    done
}

# Main
for iface in $(get_interfaces); do
    audit_interface "$iface"
done
