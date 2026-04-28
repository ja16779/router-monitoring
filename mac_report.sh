#!/bin/sh

BOT_TOKEN="REDACTED_BOT_TOKEN"
CHAT_ID="716542586"

get_vendor() {
    oui=$(echo "$1" | tr 'a-f' 'A-F' | cut -d: -f1-3 | tr -d ':')
    case "$oui" in
        7CB94C) echo "Bouffalo Lab" ;;
        B01921) echo "TP-Link" ;;
        842859) echo "Amazon" ;;
        D8F15B) echo "Espressif" ;;
        4CBCE9) echo "LG Innotek" ;;
        DC2148) echo "Intel" ;;
        EC8AC4) echo "Amazon" ;;
        CC2D8C) echo "LG Electronics" ;;
        D0A0BB) echo "Shenzhen iComm" ;;
        001599) echo "Samsung" ;;
        10D561) echo "Tuya Smart" ;;
        D81F12) echo "Tuya Smart" ;;
        805B65) echo "LG Innotek" ;;
        7CF666) echo "Xiaomi" ;;
        0CDC91) echo "Amazon" ;;
        48844E) echo "Amazon" ;;
        D8E2DF) echo "Microsoft" ;;
        D8B32F) echo "MSI/Foxconn" ;;
        74E6B8) echo "LG" ;;
        EC0DE4) echo "Xiaomi" ;;
        84B4D2) echo "Shenzhen iComm" ;;
        *)
            c2=$(echo "$1" | cut -d: -f1 | cut -c2)
            case "$c2" in 2|6|a|A|e|E) echo "Movil" ;; *) echo "-" ;; esac
            ;;
    esac
}

TMP=/tmp/mac_msg.txt
echo "DISPOSITIVOS - $(date '+%d/%m %H:%M')" > $TMP
echo "" >> $TMP

while read line; do
    mac=$(echo "$line" | awk '{print $2}')
    ip=$(echo "$line" | awk '{print $3}')
    host=$(echo "$line" | awk '{print $4}')
    [ "$host" = "*" ] && host="-"
    vendor=$(get_vendor "$mac")
    echo "$ip | $host | $vendor" >> $TMP
done < /tmp/dhcp.leases

echo "" >> $TMP
echo "Total: $(wc -l < /tmp/dhcp.leases) dispositivos" >> $TMP

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    --data-urlencode "text@${TMP}"

rm -f $TMP
