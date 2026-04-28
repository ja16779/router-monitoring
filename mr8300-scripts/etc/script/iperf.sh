#!/bin/sh
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendDocument"

sh betterspeedtest.sh -t 5 -H netperf-west.bufferbloat.net -p 1.1.1.3
iperf3 -c 121.127.43.65 --bidir
#sed -n '30p' /tmp/iperf3.out | awk {'print $7'} > /tmp/iperfdownload.out
#sed -n '27p' /tmp/iperf3.out | awk {'print $7'} > /tmp/iperfupload.out
#paste /tmp/iperfdownload.out /tmp/iperfupload.out > /tmp/iperf.out
