#!/bin/bash

LOG=~/router-check.log
TOKEN="REDACTED_BOT_TOKEN"
CHAT_ID="716542586"
DATE=$(date '+%Y-%m-%d %H:%M')
FLINT="ssh -o StrictHostKeyChecking=no -i /home/ja16779/.ssh/id_ed25519 root@192.168.10.1"
BERYL="ssh -o StrictHostKeyChecking=no -i /home/ja16779/.ssh/id_ed25519 -J root@192.168.10.1 root@192.168.10.2"

echo "=== $DATE ===" >> $LOG

# Recolectar datos Flint-2
DATOS=$($FLINT "
echo '=== SERVICIOS DNS/ADV ==='
for s in adguardhome dnsmasq; do
  echo -n \"\$s: \"; /etc/init.d/\$s status 2>&1 | head -1
done
echo '=== MAESTROS MONITOREO ==='
for m in master_realtime master_hourly master_daily master_weekly; do
  echo -n \"\$m: \"
  [ -f /usr/bin/monitor/\$m.sh ] && echo \"present\" || echo \"missing\"
done
echo '=== SERVICIOS CRITICOS ==='
for s in tailscale mwan3 crowdsec-firewall-bouncer; do
  echo -n \"\$s: \"; /etc/init.d/\$s status 2>&1 | head -1
done
echo -n \"banip: \"; /etc/init.d/banip status 2>&1 | grep 'status' | awk '{print \$3, \$4}'
echo '=== MWAN3 INTERFACES ==='
mwan3 status 2>&1 | grep -E 'online|offline'
echo '=== TEMPERATURA/RAM ==='
temp=\$(cat /sys/class/thermal/thermal_zone0/temp)
echo \"temp: \${temp}°C\"
free | awk 'NR==2{printf \"mem: %dMB used, %dMB avail\n\",\$3/1024,\$7/1024}'
echo '=== DNS CONFIG ==='
grep -E 'port.*53|listen' /etc/adguardhome/adguardhome.yaml | head -2
echo '=== CRONTAB MAESTROS ==='
crontab -l | grep -c 'master_' | awk '{print \"cron entries: \" \$1}'
echo '=== LOGS MONITOREO ==='
for log in monitor_realtime monitor_hourly monitor_daily monitor_weekly; do
  [ -f /var/log/\${log}.log ] && echo \"\${log}: \$(wc -l < /var/log/\${log}.log) lines\"
done
" 2>&1)

DATOS_BERYL=$($FLINT "
sshpass -p admin ssh -o StrictHostKeyChecking=no root@192.168.10.2 '
echo \"=== BERYL STATUS ===\"
uptime
echo \"=== RAM ===\"
free | awk \"NR==2{printf \\\"used=%dMB avail=%dMB\\\\n\\\",\\\$3/1024,\\\$7/1024}\"
echo \"=== WIFI SSIDS ===\"
iwconfig 2>/dev/null | grep -E \"SSID|Connected\" | head -4
' 2>&1
" 2>&1)

RESULTADOS="📡 Flint-2 (Principal):
$DATOS

📡 Beryl (AP):
$DATOS_BERYL"

echo "$RESULTADOS" >> $LOG

# Claude analiza
ANALISIS=$(echo "$RESULTADOS" | claude -p "Eres monitor de red OpenWrt especializado. Analiza estos datos del router. Responde SOLO con: 'ALERTAS: ninguno' si todo está bien, o 'ALERTAS: [lista de problemas]' si hay algo mal. Servicios críticos esperados: running (adguardhome, dnsmasq, tailscale, mwan3, crowdsec, banip). Maestros: 4 presentes. Temperatura < 65000. RAM > 100MB." 2>&1)

echo "Analisis: $ANALISIS" >> $LOG

# Notificar si hay alertas
if echo "$ANALISIS" | grep -qi "ALERTAS:" && ! echo "$ANALISIS" | grep -qi "ninguno"; then
    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
        --data-urlencode "text=🚨 Router Check Alert - $DATE
$ANALISIS" \
        -d "chat_id=${CHAT_ID}" > /dev/null
fi
