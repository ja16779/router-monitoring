#!/bin/sh
TOKEN="REDACTED_BOT_TOKEN"
ID="716542586"
URL="https://api.telegram.org/bot$TOKEN/sendDocument"
arp_file="/tmp/arps.txt"

rm /tmp/arps.txt
rm /tmp/charur.txt

cat /proc/net/arp | awk 'NR>1 {print $1 " " $4}' > "$arp_file"
for ip in $(cat /proc/net/arp | grep -v IP | awk '{print $1}'); do 
    grep $ip /tmp/dhcp.leases >> /tmp/usuarios-${HOSTNAME}-$(date +%F).log; 
done
for t in $(cat /tmp/dhcp.leases | awk '{print $1}'); do
  date -d @$t >>/tmp/usuariosfecha-${HOSTNAME}-$(date +%F).log
done
 paste /tmp/dhcp.leases /tmp/usuariosfecha-${HOSTNAME}-$(date +%F).log > /tmp/usuariosconectados-${HOSTNAME}-$(date +%F).log

for a in $(cat $arp_file | awk '{print $1}'); do
   grep $a /tmp/usuariosconectados-${HOSTNAME}-$(date +%F).log  >> /tmp/charur.txt
done

cat /tmp/charur.txt | awk '{print $3}' | while read ip; do
    # Ping the host with a timeout of 1 second and count 1 ping
    if ping -c 1 -W 1 $ip &> /dev/null; then
        # If the host is reachable, show its details
        awk -v ip=$ip '$3 == ip {print $2,$3,$4,$5}' /tmp/charur.txt
    fi
done



#paste /tmp/dhcp.leases /tmp/usuariosfecha-${HOSTNAME}-$(date +%F).log > /tmp/usuariosconectados-${HOSTNAME}-$(date +%F).log

MENSAJE="Usuarios Conectados /etc/script/usuariosconectados-${HOSTNAME}-$(date +%F).log"
#curl -s -X POST $URL -F chat_id=$ID -F document="@/etc/script/usuariosconectados-${HOSTNAME}-$(date +%F).log"
