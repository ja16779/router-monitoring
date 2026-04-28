#!/bin/sh

# Lista de interfaces WAN (ajusta según tu configuración)
INTERFACES="pppoe-wan lan5"

# URL para obtener la IP pública
IP_SERVICE="https://ipinfo.io/ip"

# Verifica si curl está instalado
if ! command -v curl >/dev/null 2>&1; then
    echo "❌ curl no está instalado. Instálalo con: opkg update && opkg install curl"
    exit 1
fi

echo "🔍 Obteniendo IP pública por interfaz..."

for iface in $INTERFACES; do
    echo "🌐 Interfaz: $iface"
    IP=$(curl -s --interface "$iface" "$IP_SERVICE")
    if echo "$IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "✅ IP pública ($iface): $IP"
    else
        echo "⚠️  No se pudo obtener IP pública para $iface (resultado: $IP)"
    fi
done
