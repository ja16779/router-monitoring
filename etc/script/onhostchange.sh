#!/bin/sh
# Script de notificacion WiFi via Telegram
# Notifica conexiones y desconexiones de dispositivos

# Configuracion
DHCP_LEASES="/tmp/dhcp.leases"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"

# Mapeo de interfaces a ESSID
get_essid() {
    case "$1" in
        wlan0)   echo "IOT" ;;
        wlan0-1) echo "Mega_2.4G_A2DF" ;;
        wlan1)   echo "AXTEL XTREMO" ;;
        wlan1-1) echo "Mega_5G_A2DF" ;;
        *)       echo "Unknown"; return 1 ;;
    esac
}

# Obtener informacion del cliente desde DHCP leases
get_client_info() {
    local mac="$1"
    local lease_line
    lease_line="$(grep -i "$mac" "$DHCP_LEASES")"

    CLIENT_IP="$(echo "$lease_line" | awk '{print $3}')"
    CLIENT_HOSTNAME="$(echo "$lease_line" | awk '{print $4}')"

    [ "$CLIENT_HOSTNAME" = "*" ] || [ -z "$CLIENT_HOSTNAME" ] && CLIENT_HOSTNAME="NONAME"
}

# Enviar mensaje a Telegram
send_telegram() {
    local message="$1"

    logger -p local0.info -t dhcp-notify "$message"

    [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && {
        logger -p local0.err -t dhcp-notify "Error: Token o chat_id vacio"
        return 1
    }

    curl -skim 10 \
        --data disable_notification="false" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$message" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

# Validar argumentos
[ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] && exit 1

INTERFACE="$1"
EVENT="$2"
MAC="$3"

ESSID="$(get_essid "$INTERFACE")" || exit 1
get_client_info "$MAC"

SAFE_HOSTNAME="$(echo "$CLIENT_HOSTNAME" | sed 's/[^a-zA-Z0-9]//g')"
TIMESTAMP="$(date '+%A %d-%b-%Y %T')"

case "$EVENT" in
    AP-STA-CONNECTED)
        BITRATE="$(iwinfo "$INTERFACE" info | awk '/Bit Rate:/{print $3, $4}')"
        send_telegram "<b>#${SAFE_HOSTNAME}</b> connected on <b>#${ESSID}</b>
<pre>
Time: ${TIMESTAMP}
Hostname: ${CLIENT_HOSTNAME}
IP Address: ${CLIENT_IP}
MAC Address: ${MAC}
ESSID: ${ESSID}
BitRate: ${BITRATE}
</pre>"
        ;;
    AP-STA-DISCONNECTED)
        send_telegram "<b>#${SAFE_HOSTNAME}</b> disconnected from <b>#${ESSID}</b>
<pre>
Time: ${TIMESTAMP}
Hostname: ${CLIENT_HOSTNAME}
IP Address: ${CLIENT_IP}
MAC Address: ${MAC}
ESSID: ${ESSID}
</pre>"
        ;;
esac
