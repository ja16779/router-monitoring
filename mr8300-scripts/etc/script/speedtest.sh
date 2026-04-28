#!/bin/sh
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendDocument"

#sh betterspeedtest.sh -t 5 -H netperf-west.bufferbloat.net -p 1.1.1.3 > /tmp/izzispeed-${HOSTNAME}-$(date +%F).log
sh /etc/script/speedtest-netperf.sh -t 15 -H netperf-west.bufferbloat.net -p 1.1.1.1 --concurrent > /tmp/speedtest.out
#curl -s -X POST $URL -F chat_id=$ID -F document="@/tmp/megacablespeed-${HOSTNAME}-$(date +%F).log"
