#!/bin/sh

#TOKEN="REDACTED_BOT_TOKEN"
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"
MENSAJE="IP Publica,$(curl --interface lan5 ifconfig.me)"
#curl -s -X POST $URL -d chat_id=$ID -d text="$MENSAJE"
MENSAJE="IP Privada Mega:$(ifconfig lan5 | grep 192.168 | awk '{print $2}')"
#curl -s -X POST $URL -d chat_id=$ID -d text="$MENSAJE"



curl --interface lan5 ifconfig.me > /tmp/ipnew.log

cmp /tmp/ipnew.log /tmp/ipold.log

if [ "$?" = "0" ]; then

#echo -e "Subject:Izzi sin cambios `date` " "\n\n`date` Axtel sin Cambios"
#logger -p notice -t Opendns "Megacable sin cambios"
MENSAJE="$(uname -n):Megacable Sin Cambios"
#URL="https://api.telegram.org/bot$TOKEN/sendMessage"

#curl -s -X POST $URL -d chat_id=$ID -d text="$MENSAJE"

echo $MENSAJE

else

curl --interface lan5 --basic --user ja16779@gmail.com:Pinche0! https://updates.opendns.com/nic/update?hostname=Casa

echo -e "Subject:Actualizando IP Axtel `date` " "\n\n`date` Actualizando IP Mega"
logger Â´p notice -t Opendns   " Mega con cambios"
MENSAJE="$(uname -n):Mega Con Cambios"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"

curl -s -X POST $URL -d chat_id=$ID -d text="$MENSAJE" > /dev/null

mv /tmp/ipnew.log /tmp/ipold.log

fi

