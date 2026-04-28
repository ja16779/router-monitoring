#TOKEN="REDACTED_BOT_TOKEN"
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendMessage"




if [ "$2" = "AP-STA-CONNECTED" ]; then
  MENSAJE=$(echo "someone has connected with mac id $3 on $1")
   curl -s -X POST "$URL" -d chat_id="$ID" -d text="$MENSAJE"
echo "Prueba $2 $3 $4"

fi

if [ "$2" = "AP-STA-DISCONNECTED" ]; then
  echo "someone has disconnected with mac id $3 on $1"
echo "Prueba $2 $3 $4"
fi
