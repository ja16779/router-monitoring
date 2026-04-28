#!/bin/sh

# Define your Telegram bot token, chat ID, and URL
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"

# Define the SSIDs for each service
SSID_if2g="SMARTHOME"
SSID_if2ga2df="Mega_2.4G_A2DF"
SSID_if5ga2df="Mega_5G_A2DF"
SSID_if5g="AXTEL XTREMO_5G"
#SSID_if5gn="AXTEL XTREMO_5GN"
#SSID_mesh2g="MR8300_2G"
#SSID_mesh5gac="MR8300_5G"
#SSID_smarthome="SMARTHOME"

# Function to send messages via Telegram
send_telegram_message() {
    local message="$1"
    curl -s -X POST "$URL" -d chat_id="$ID" -d text="$message"
}

# Function to check if a service is running and handle accordingly
check_service() {
    local service_name="$1"
    local service_command="$2"
    
    # Assign the correct SSID based on the service name
    case "$service_name" in
         "wlan0-1")
             ssid="$SSID_if2ga2df"
             ;;
          "wlan0")
              ssid="$SSID_if2g"
              ;;
         "wlan1")
             ssid="$SSID_if5g"
             ;;
         "wlan1-1")
             ssid="$SSID_if5ga2df"
             ;;
        # "if5gn")
        #     ssid="$SSID_if5gn"
        #     ;;
        #"mesh2g")
        #    ssid="$SSID_mesh2g"
        #    ;;
        #"mesh5gac")
        #    ssid="$SSID_mesh5gac"
        #    ;;
	#"smarthome")
	#    ssid="SSID_smarthome"
	#    ;;
        *)
            ssid="Unknown"
            ;;
    esac

    if pgrep -f "$service_name" > /dev/null; then
        # Service is running
        local message="$(uname -n): Servicio $service_name Corriendo (SSID: $ssid)"
        logger -p notice -t "$service_name" "$message"
        send_telegram_message "$message" > /dev/null
    else
        # Service is not running, start it
        $service_command
        local message="$(uname -n): Levantando Servicio $service_name (SSID: $ssid)"
        send_telegram_message "$message"
        logger -p notice -t "$service_name" "$message" /dev/null
    fi
}

# Check services and assign SSIDs
check_service "wlan0" "hostapd_cli -a /etc/script/onhostchange.sh -i wlan0 -B"
check_service "wlan0-1" "hostapd_cli -a /etc/script/onhostchange.sh -i wlan0-1 -B"
check_service "wlan1" "hostapd_cli -a /etc/script/onhostchange.sh -i wlan1 -B"
check_service "wlan1-1" "hostapd_cli -a /etc/script/onhostchange.sh -i wlan1-1 -B"
#check_service "if5gn" "hostapd_cli -a /etc/script/onhostchange.sh -i if5gn -B"
#check_service "mesh2g" "hostapd_cli -a /etc/script/onhostchange.sh -i mesh2g -B"
#check_service "mesh5gac" "hostapd_cli -a /etc/script/onhostchange.sh -i mesh5gac -B"
#check_service "smarthome" "hostapd_cli -a /etc/script/onhostchange.sh -i smarthome -B"

