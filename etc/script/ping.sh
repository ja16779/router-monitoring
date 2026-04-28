#!/bin/sh

send_to_telegram() {
    logger -p local0.info -t dhcp-join-notify "$1"
    token="REDACTED_BOT_TOKEN"
    chat_id="716542586"

    if [ -n "$token" ] && [ -n "$chat_id" ]; then
        curl -s --max-time 10 \
            --data disable_notification="false" \
            --data parse_mode="MarkdownV2" \
            --data chat_id="$chat_id" \
            --data-urlencode "text=$1" \
            "https://api.telegram.org/bot${token}/sendMessage" > /dev/null
    else
        logger -p local0.info -t dhcp-join-notify "Error: Telegram chat_id or token is empty"
    fi
}

rm -f /tmp/fping.txt

# Escanear dos subredes
fping -a -q -g 192.168.8.0/24 | grep -v "duplicate" >> /tmp/fping.txt
fping -a -q -g 192.168.10.0/24 | grep -v "duplicate" >> /tmp/fping.txt

usuarios=$(wc -l < /tmp/fping.txt)
device_name=$(cat /tmp/sysinfo/model | sed 's/[^a-zA-Z0-9]//g')

# Construir listado con IP - Nombre
listado=""
while read ip; do
    nombre=$(nslookup "$ip" 2>/dev/null | awk -F'= ' '/name/ {print $2}' | sed 's/\.$//')
    [ -z "$nombre" ] && nombre="NONAME"
    safe_nombre=$(echo "$nombre" | sed 's/[^a-zA-Z0-9]//g')
    listado="$listado\n${ip} - ${safe_nombre}"
done < /tmp/fping.txt

# Mensaje final
mensaje="\#USUARIOS CONECTADOS:$usuarios \#${device_name}:
\`\`\`
Time: $(date "+%A %d-%b-%Y %T")
Usuarios Conectados: $usuarios
$listado
\`\`\`"

send_to_telegram "$mensaje"
