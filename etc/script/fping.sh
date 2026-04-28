#!/bin/sh

send_to_telegram() {
    logger -p local0.info -t dhcp-join-notify "$1"
    #token="REDACTED_BOT_TOKEN"
    token="REDACTED_BOT_TOKEN"
    chat_id="716542586"
    if [[ -n "${token}" ]] && [[ -n "${chat_id}" ]]; then
        curl -skim 10 --data disable_notification="false" --data parse_mode="MarkdownV2" --data chat_id="$chat_id" --data-urlencode "text=$1" "https://api.telegram.org/bot${token}/sendMessage" > /dev/null
    else
        logger -p local0.info -t dhcp-join-notify "Error: Your telegram chat_id or token is empty"
    fi

}
#TOKEN="REDACTED_BOT_TOKEN"
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"

rm /tmp/fping.txt

fping -a -q -g 192.168.8.0/24 | grep -v "duplicate" >> /tmp/fping.txt
fping -a -q -g 192.168.10.0/24 | grep -v "duplicate" >> /tmp/fping.txt

usuarios=$(($(wc -l < /tmp/fping.txt) - 2))
#usuarios=$(wc -l /tmp/fping.txt | awk {'print $1'})

#curl -s -X POST $URL -d chat_id=$ID -d text="Usuarios Conectados $usuarios"

device_name=$(cat /tmp/sysinfo/model | sed 's/[^a-zA-Z0-9]//g')

send_to_telegram "\#$(echo "${hostname}" | sed 's/[^a-zA-Z0-9]//g') USUARIOS CONECTADOS\#$usuarios \#${device_name}:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Usuarios Conectados: $usuarios
\`\`\`"
