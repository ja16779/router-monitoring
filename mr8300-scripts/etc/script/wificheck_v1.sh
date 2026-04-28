#!/bin/sh

# Telegram bot credentials
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# Lista de interfaces a monitorear
IFACES="wlan0 wlan0-1 wlan1 wlan1-1"

# SSID mapping
get_ssid() {
    case "$1" in
        wlan0)   echo "IOT" ;;
        wlan0-1) echo "Mega_2.4G_A2DF" ;;
        wlan1)   echo "AXTEL XTREMO" ;;
        wlan1-1) echo "Mega_5G_A2DF" ;;
        *)       echo "Desconocido" ;;
    esac
}

# Send Telegram message
send_telegram_message() {
    message="$1"
    curl -s -X POST "$URL" \
        -d chat_id="$ID" \
        --data-urlencode "text=$message" >/dev/null
}

# Rutina de chequeo con evaluación de pgrep
check_service() {
    iface="$1"
    ssid=$(get_ssid "$iface")
    command="hostapd_cli -a /etc/script/onhostchange.sh -i $iface -B"

    # Ejecutar pgrep y evaluar resultado
    pgrep -f "(^|[[:space:]])$iface($|[[:space:]])" >/dev/null
    status=$?   # 0 si existe, 1 si no existe

    if [ $status -eq 0 ]; then
        msg="$(uname -n): Servicio $iface corriendo (SSID: $ssid)"
        logger -p notice -t "$iface" "$msg"
        #send_telegram_message "$msg"
    else
        if eval "$command"; then
            msg="$(uname -n): Levantando servicio $iface (SSID: $ssid)"
        else
            msg="$(uname -n): ERROR al levantar servicio $iface (SSID: $ssid)"
        fi
        logger -p notice -t "$iface" "$msg"
        send_telegram_message "$msg"
    fi
}

# Bucle principal
for iface in $IFACES; do
    check_service "$iface"
done
