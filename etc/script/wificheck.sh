#!/bin/sh

# Telegram bot credentials
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# SSID mapping
get_ssid() {
    case "$1" in
        wlan0)   echo "IOT" ;;
        wlan0-1) echo "Mega_2.4G_A2DF" ;;
        wlan1)   echo "AXTEL XTREMO" ;;
        wlan1-1) echo "Mega_5G_A2DF" ;;
        #phy1-ap0) echo "IOT5G" ;;
        *)       echo "Desconocido" ;;
    esac
}

#ps | grep hostchange.sh | xargs kill


# Send Telegram message
send_telegram_message() {
    message="$1"
    curl -s -X POST "$URL" \
        -d chat_id="$ID" \
        --data-urlencode "text=$message" >/dev/null
}

# Check and manage service
check_service() {
    iface="$1"
    command="$2"
    ssid=$(get_ssid "$iface")

    # Buscar específicamente hostapd_cli con esa interfaz
    #if ps | grep "[h]ostapd_cli" | grep -q "\-i $iface"; then
    if pgrep -f '(^|[[:space:]])$iface($|[[:space:]])'; then
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

# Check all interfaces
check_service "wlan0"   "hostapd_cli -a /etc/script/hostchange.sh -i wlan0 -B"
check_service "wlan0-1" "hostapd_cli -a /etc/script/hostchange.sh -i wlan0-1 -B"
check_service "wlan1"   "hostapd_cli -a /etc/script/hostchange.sh -i wlan1 -B"
check_service "wlan1-1" "hostapd_cli -a /etc/script/hostchange.sh -i wlan1-1 -B"
#check_service "phy1-ap0" "hostapd_cli -a /etc/script/hostchange.sh -i phy1-ap0 -B"
