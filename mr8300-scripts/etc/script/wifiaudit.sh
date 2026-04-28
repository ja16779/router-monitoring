#!/bin/sh
# Script: audit-disable-11kv.sh
# Audita y desactiva 802.11k/v en todos los wifi-iface de OpenWrt

echo "🔍 Auditoría de interfaces WiFi (ieee80211k/v)..."
for iface in $(uci show wireless | grep "=wifi-iface" | cut -d. -f2 | cut -d= -f1); do
    k_val=$(uci get wireless.$iface.ieee80211k 2>/dev/null)
    v_val=$(uci get wireless.$iface.ieee80211v 2>/dev/null)

    echo "Interface: $iface"
    echo "   ieee80211k: ${k_val:-no definido}"
    echo "   ieee80211v: ${v_val:-no definido}"

    if [ "$k_val" = "1" ] || [ "$v_val" = "1" ]; then
        echo "   ➡️ Deshabilitando 802.11k/v en $iface..."
        uci set wireless.$iface.ieee80211k='0'
        uci set wireless.$iface.ieee80211v='0'
    fi
done

# Guardar cambios
uci commit wireless

# Recargar WiFi para aplicar
#wifi reload

echo "✅ Auditoría completa. Todas las interfaces ahora tienen 802.11k/v deshabilitado."
