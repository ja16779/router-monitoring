#!/bin/sh
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

CPU0=$(awk '/^cpu0/{t=$2+$3+$4+$5+$6+$7+$8;i=$5;if(t>0)print int((t-i)*100/t);else print 0}' /proc/stat)
CPU1=$(awk '/^cpu1/{t=$2+$3+$4+$5+$6+$7+$8;i=$5;if(t>0)print int((t-i)*100/t);else print 0}' /proc/stat)
CPU2=$(awk '/^cpu2/{t=$2+$3+$4+$5+$6+$7+$8;i=$5;if(t>0)print int((t-i)*100/t);else print 0}' /proc/stat)
CPU3=$(awk '/^cpu3/{t=$2+$3+$4+$5+$6+$7+$8;i=$5;if(t>0)print int((t-i)*100/t);else print 0}' /proc/stat)

UPTIME=$(awk '{print int($1)}' /proc/uptime)
LOAD=$(awk '{print $1}' /proc/loadavg)
TEMP=$(awk '{print int($1/1000)}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0)
MEM_TOTAL=$(awk '/MemTotal/{print $2}' /proc/meminfo)
MEM_FREE=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
MEM_PCT=$(( (MEM_TOTAL - MEM_FREE) * 100 / MEM_TOTAL ))
INET=$(ping -c1 -W1 8.8.8.8 >/dev/null 2>&1 && echo true || echo false)
CONNS=$(wc -l < /proc/net/nf_conntrack 2>/dev/null || echo 0)

WIFI_2G=0; WIFI_5G=0
for iface in wlan0 wlan0-1 wlan1 wlan1-1; do
    cnt=$(iwinfo $iface assoclist 2>/dev/null | grep -c dBm)
    case $iface in wlan0|wlan0-1) WIFI_2G=$((WIFI_2G+cnt));; wlan1|wlan1-1) WIFI_5G=$((WIFI_5G+cnt));; esac
done
WIFI_TOTAL=$((WIFI_2G+WIFI_5G))

DHCP_IOT=$(grep -c '192.168.8.' /tmp/dhcp.leases 2>/dev/null || echo 0)
DHCP_LAN=$(grep -c '192.168.10.' /tmp/dhcp.leases 2>/dev/null || echo 0)

rx_eth1=$(cat /sys/class/net/eth1/statistics/rx_bytes 2>/dev/null || echo 0)
tx_eth1=$(cat /sys/class/net/eth1/statistics/tx_bytes 2>/dev/null || echo 0)
rx_lan5=$(cat /sys/class/net/lan5/statistics/rx_bytes 2>/dev/null || echo 0)
tx_lan5=$(cat /sys/class/net/lan5/statistics/tx_bytes 2>/dev/null || echo 0)
rx_lan=$(cat /sys/class/net/br-lan/statistics/rx_bytes 2>/dev/null || echo 0)
tx_lan=$(cat /sys/class/net/br-lan/statistics/tx_bytes 2>/dev/null || echo 0)
rx_iot=$(cat /sys/class/net/br-lan.8/statistics/rx_bytes 2>/dev/null || echo 0)
tx_iot=$(cat /sys/class/net/br-lan.8/statistics/tx_bytes 2>/dev/null || echo 0)

mwan_out=$(mwan3 status 2>/dev/null)
wan_status=$(echo "$mwan_out" | grep 'interface wan ' | grep -q online && echo online || echo offline)
wan_online=$(echo "$mwan_out" | grep 'interface wan ' | sed -n 's/.*online \([^,)]*\).*/\1/p')
[ -z "$wan_online" ] && wan_online="--"
wan2_status=$(echo "$mwan_out" | grep 'interface secondwan ' | grep -q online && echo online || echo offline)
wan2_online=$(echo "$mwan_out" | grep 'interface secondwan ' | sed -n 's/.*online \([^,)]*\).*/\1/p')
[ -z "$wan2_online" ] && wan2_online="--"

# SQM stats WAN1
sqm1=$(tc -s qdisc show dev eth1 2>/dev/null)
sqm1_bw=$(echo "$sqm1" | grep -o 'bandwidth [0-9A-Za-z]*' | awk '{print $2}')
sqm1_cap=$(echo "$sqm1" | grep -o 'capacity estimate: [0-9A-Za-z]*' | awk '{print $3}')
sqm1_drop=$(echo "$sqm1" | sed -n 's/.*dropped \([0-9]*\).*/\1/p' | head -1)
sqm1_sent=$(echo "$sqm1" | awk '/Sent/{print $2}' | head -1)
sqm1_diffserv=$(echo "$sqm1" | awk '/^  bytes/{print $2,$3,$4,$5}')
sqm1_bulk=$(echo $sqm1_diffserv | awk '{print $1}'); [ -z "$sqm1_bulk" ] && sqm1_bulk=0
sqm1_besteffort=$(echo $sqm1_diffserv | awk '{print $2}'); [ -z "$sqm1_besteffort" ] && sqm1_besteffort=0
sqm1_video=$(echo $sqm1_diffserv | awk '{print $3}'); [ -z "$sqm1_video" ] && sqm1_video=0
sqm1_voice=$(echo $sqm1_diffserv | awk '{print $4}'); [ -z "$sqm1_voice" ] && sqm1_voice=0
[ -z "$sqm1_bw" ] && sqm1_bw="--"
[ -z "$sqm1_cap" ] && sqm1_cap="--"
[ -z "$sqm1_drop" ] && sqm1_drop=0
[ -z "$sqm1_sent" ] && sqm1_sent=0

# SQM stats WAN2
sqm2=$(tc -s qdisc show dev lan5 2>/dev/null)
sqm2_bw=$(echo "$sqm2" | grep -o 'bandwidth [0-9A-Za-z]*' | awk '{print $2}')
sqm2_cap=$(echo "$sqm2" | grep -o 'capacity estimate: [0-9A-Za-z]*' | awk '{print $3}')
sqm2_drop=$(echo "$sqm2" | sed -n 's/.*dropped \([0-9]*\).*/\1/p' | head -1)
sqm2_sent=$(echo "$sqm2" | awk '/Sent/{print $2}' | head -1)
sqm2_diffserv=$(echo "$sqm2" | awk '/^  bytes/{print $2,$3,$4,$5}')
sqm2_bulk=$(echo $sqm2_diffserv | awk '{print $1}'); [ -z "$sqm2_bulk" ] && sqm2_bulk=0
sqm2_besteffort=$(echo $sqm2_diffserv | awk '{print $2}'); [ -z "$sqm2_besteffort" ] && sqm2_besteffort=0
sqm2_video=$(echo $sqm2_diffserv | awk '{print $3}'); [ -z "$sqm2_video" ] && sqm2_video=0
sqm2_voice=$(echo $sqm2_diffserv | awk '{print $4}'); [ -z "$sqm2_voice" ] && sqm2_voice=0
[ -z "$sqm2_bw" ] && sqm2_bw="--"
[ -z "$sqm2_cap" ] && sqm2_cap="--"
[ -z "$sqm2_drop" ] && sqm2_drop=0
[ -z "$sqm2_sent" ] && sqm2_sent=0

for iface in wlan0 wlan0-1 wlan1 wlan1-1; do
    case $iface in wlan0|wlan0-1) band="2.4G";; wlan1|wlan1-1) band="5G";; esac
    ssid=$(iwinfo $iface info 2>/dev/null | awk -F'"' '/ESSID/{print $2}')
    [ -z "$ssid" ] && ssid="Unknown"
    iwinfo $iface assoclist 2>/dev/null | grep dBm | while read mac rest; do
        sig=$(echo "$rest" | awk '{print $1}')
        nm=$(awk -v m="$mac" 'tolower($2)==tolower(m){print $4}' /tmp/dhcp.leases 2>/dev/null | head -1)
        [ -z "$nm" ] && nm="$mac"
        printf '{"mac":"%s","signal":%s,"band":"%s","ssid":"%s","name":"%s"},' "$mac" "$sig" "$band" "$ssid" "$nm"
    done
done > /tmp/wcl.tmp
wifi_json=$(cat /tmp/wcl.tmp 2>/dev/null | sed 's/,$//')
rm -f /tmp/wcl.tmp

top_json=$(awk -F'[= ]' '{for(i=1;i<=NF;i++)if($i=="src"&&$(i+1)~/^192\.168\./)print $(i+1)}' /proc/net/nf_conntrack 2>/dev/null | sort | uniq -c | sort -rn | head -5 | awk '{printf"{\"ip\":\"%s\",\"conns\":%d},",$2,$1}' | sed 's/,$//')

NOW=$(date +%s)
dhcp_json=$(awk -v now="$NOW" '{r=$1-now;n=$4;if(n=="")n="*";printf"{\"ip\":\"%s\",\"mac\":\"%s\",\"name\":\"%s\",\"remain\":%d},",$3,$2,n,r}' /tmp/dhcp.leases 2>/dev/null | sed 's/,$//')

# Build DNS cache from dnsmasq log (IP -> domain) - cached and reply entries
grep -E '(cached|reply).*is [0-9]' /tmp/dnsmasq.log 2>/dev/null | tail -2000 | sed -n 's/.*\(cached\|reply\) \([^ ]*\) is \([0-9][0-9.]*\).*/\3 \2/p' | sort -u > /tmp/dns_cache.tmp

# Build local hosts cache from DHCP leases (IP -> name)
awk '{print $3,$4}' /tmp/dhcp.leases 2>/dev/null >> /tmp/dns_cache.tmp

conn_json=$(awk -F'[= ]' -v cache="/tmp/dns_cache.tmp" '
BEGIN{while((getline line < cache)>0){split(line,a," ");dns[a[1]]=a[2]}}
NR<=30&&/^ipv4/{
    p=($3==6?"TCP":"UDP");s="";d="";sp="";dp="";b=0;st="-"
    for(i=1;i<=NF;i++){
        if($i=="src"&&s=="")s=$(i+1)
        if($i=="dst"&&d=="")d=$(i+1)
        if($i=="sport"&&sp=="")sp=$(i+1)
        if($i=="dport"&&dp=="")dp=$(i+1)
        if($i=="bytes")b=$(i+1)
    }
    if(/ESTABLISHED/)st="EST";else if(/TIME_WAIT/)st="TW"
    src_name=(s in dns)?dns[s]:"-"
    dst_name=(d in dns)?dns[d]:"-"
    if(s!=""&&d!="")printf"{\"proto\":\"%s\",\"src\":\"%s\",\"dst\":\"%s\",\"sport\":\"%s\",\"dport\":\"%s\",\"bytes\":%d,\"state\":\"%s\",\"src_dns\":\"%s\",\"dst_dns\":\"%s\"},",p,s,d,sp,dp,b,st,src_name,dst_name
}' /proc/net/nf_conntrack 2>/dev/null | sed 's/,$//')
rm -f /tmp/dns_cache.tmp


cat << ENDJSON
{
  "system":{"uptime":$UPTIME,"load":"$LOAD","temp":$TEMP,"mem_pct":$MEM_PCT,"internet":$INET,"connections":$CONNS,"cpu":[$CPU0,$CPU1,$CPU2,$CPU3]},
  "clients":{"wifi_total":$WIFI_TOTAL,"wifi_2g":$WIFI_2G,"wifi_5g":$WIFI_5G,"dhcp_iot":$DHCP_IOT,"dhcp_lan":$DHCP_LAN},
  "traffic":{"wan":{"rx":$rx_eth1,"tx":$tx_eth1,"status":"$wan_status","online":"$wan_online"},"wan2":{"rx":$rx_lan5,"tx":$tx_lan5,"status":"$wan2_status","online":"$wan2_online"},"lan":{"rx":$rx_lan,"tx":$tx_lan},"iot":{"rx":$rx_iot,"tx":$tx_iot}},
  "sqm":{"wan":{"bw":"$sqm1_bw","capacity":"$sqm1_cap","sent":$sqm1_sent,"dropped":$sqm1_drop,"bulk":$sqm1_bulk,"besteffort":$sqm1_besteffort,"video":$sqm1_video,"voice":$sqm1_voice},"wan2":{"bw":"$sqm2_bw","capacity":"$sqm2_cap","sent":$sqm2_sent,"dropped":$sqm2_drop,"bulk":$sqm2_bulk,"besteffort":$sqm2_besteffort,"video":$sqm2_video,"voice":$sqm2_voice}},
  "wifi_clients":[$wifi_json],
  "top_clients":[$top_json],
  "dhcp_leases":[$dhcp_json],
  "active_conns":[$conn_json]
}
ENDJSON
