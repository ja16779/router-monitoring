#!/bin/sh
# Dashboard de estado

clear
echo "======================================="
echo "   MONITOR DE ESTADO - OPENWRT"
echo "======================================="

HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || echo "OpenWrt")
FECHA=$(date '+%Y-%m-%d %H:%M:%S')

echo "Host: $HOSTNAME"
echo "Fecha: $FECHA"
echo "---------------------------------------"

# Sistema
echo "[SISTEMA]"
UPTIME=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
LOAD=$(cat /proc/loadavg | awk '{print $1}')
echo "  Uptime: $UPTIME"
echo "  Load: $LOAD"

MEM=$(free | grep Mem | awk '{printf "%.0f%%", $3/$2*100}')
echo "  RAM: $MEM"

TEMP="N/A"
[ -f /sys/class/thermal/thermal_zone0/temp ] && TEMP="$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))C"
echo "  Temp: $TEMP"

echo "---------------------------------------"

# Red
echo "[RED]"
if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "  Internet: OK Conectado"
else
    echo "  Internet: XX Desconectado"
fi

CONEXIONES=$(cat /proc/net/nf_conntrack 2>/dev/null | wc -l)
echo "  Conexiones: $CONEXIONES"

DHCP=$(wc -l < /tmp/dhcp.leases 2>/dev/null || echo 0)
echo "  Clientes DHCP: $DHCP"

echo "---------------------------------------"

# Servicios
echo "[SERVICIOS]"
for SVC in dnsmasq dropbear odhcpd; do
    if pgrep -x "$SVC" > /dev/null 2>&1; then
        echo "  OK $SVC"
    else
        echo "  XX $SVC"
    fi
done

echo "======================================="
