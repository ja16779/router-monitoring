#!/bin/sh

#TOKEN="REDACTED_BOT_TOKEN"
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"
MENSAJE="Router Reiniciado at $(date)"
curl -s -X POST $URL -d chat_id=$ID -d text="$MENSAJE" > /dev/null
ntpdate 0.openwrt.pool.ntp.org
sleep 30
/etc/init.d/qosmate start
opkg update
