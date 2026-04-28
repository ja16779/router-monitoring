#!/bin/sh

name="/tmp/dhcp.leases"
#TOKEN="REDACTED_BOT_TOKEN"
#TOKEN="REDACTED_BOT_TOKEN"
#ID="716542586"
#URL="https://api.telegram.org/bot$TOKEN/sendMessage"

send_to_telegram() {
    logger -p local0.info -t dhcp-remove-notify "$1"
    #token="REDACTED_BOT_TOKEN"
    token="REDACTED_BOT_TOKEN"
    chat_id="716542586"
    if [[ -n "${token}" ]] && [[ -n "${chat_id}" ]]; then
        curl -skim 10 --data disable_notification="false" --data parse_mode="MarkdownV2" --data chat_id="$chat_id" --data-urlencode "text=$1" "https://api.telegram.org/bot${token}/sendMessage" > /dev/null
    else
        logger -p local0.info -t wifi_connection "Error: Your telegram chat_id or token is empty"
    fi
}


case "$1" in
     wlan0-0)
         ESSID="AXTEL XTREMO"
         ;;
     wlan0-1)
         ESSID="Mega_2.4G_A2DF"
         ;;
     wlan1-1)
         ESSID="Mega_5G_A2DF"
         ;;
     wlan1-0)
         ESSID="AXTEL XTREMO"
         ;;
    *)
        echo "Unknown identifier: $1"
        exit 1
        ;;
esac

if [ "$2" = "AP-STA-CONNECTED" ]; then

  ipaddress=$(grep -i "$3" "$name" | awk '{print $3}')
  hostname=$(grep -i "$3" "$name" | awk '{print $4}')
  if [ "$hostname" = "*" ]; then
  hostname="NONAME"
  fi

  mac=$(grep -i "$3" "$name") 
  mac1=$(echo $mac | awk '{print $4, "con ip" ,$3,"y mac", $2}')
  msg1=$(echo $mac | awk '{print $4}')
  
  BitRate=$(iwinfo "$1" info | grep "Bit Rate:" | awk '{print $3, $4}')

  msg="$mac1 conectado en $ESSID en $HOSTNAME y $BitRate"
  MENSAJE=$(echo $msg | awk '{ print toupper($0) }')
  #curl -s -X POST "$URL" -d chat_id="$ID" -d text="$MENSAJE"
  #echo -e "Subject:$msg1 "conectado"\n\n`date` $msg" >> /etc/script/conectado-${HOSTNAME}-$(date +%F).log
  #logger -p notice -t "$msg"
  
send_to_telegram "\#$(echo "${hostname}" | sed 's/[^a-zA-Z0-9]//g') connected on \#${ESSID}:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Hostname: ${hostname}
IP Address: ${ipaddress}
MAC Address: $3
ESSID: ${ESSID}
BitRate: ${BitRate}
\`\`\`"
#  sleep 30

#  arp-scan -qxlN -I br-lan | awk '{print $1}' | xargs fping -q -c1
#  arp-scan -qxlN -I br-guest | awk '{print $1}' | xargs fping -q -c1

#  sleep 20

#  /etc/script/total.sh

fi

if [ "$2" = "AP-STA-DISCONNECTED" ]; then

  ipaddress=$(grep -i "$3" "$name" | awk '{print $3}')
  hostname=$(grep -i "$3" "$name" | awk '{print $4}')
  if [ "$hostname" = "*" ]; then
  hostname="NONAME"
  fi
  mac=$(grep -i "$3" "$name")
  mac1=$(echo $mac | awk '{print $4, "con ip" ,$3,"y mac", $2}')

  #msg="$mac1 desconectado de $ESSID de $HOSTNAME"
  #MENSAJE=$(echo $msg | awk '{ print toupper($0) }')
  #curl -s -X POST "$URL" -d chat_id="$ID" -d text="$MENSAJE"
  #echo -e "Subject:$msg1 "desconectado"\n\n`date` $msg" >> /etc/script/desconectado-${HOSTNAME}-$(date +%F).log
  #logger -p notice -t "$msg"

send_to_telegram "\#$(echo "${hostname}" | sed 's/[^a-zA-Z0-9]//g') disconnected from \#${ESSID}:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Hostname: ${hostname}
IP Address: ${ipaddress}
MAC Address: $3
ESSID: ${ESSID}
\`\`\`"


fi
