#!/bin/sh
# Script para configurar acceso a impresora Samsung desde LAN a IOT

# Eliminar posibles reglas antiguas con formato incorrecto
uci -q delete firewall.@rule[8] 2>/dev/null || true
uci -q delete firewall.@rule[9] 2>/dev/null || true
uci -q delete firewall.@rule[10] 2>/dev/null || true

# Limpiar cualquier regla existente con nombres de impresora
for i in $(seq 0 50); do
    name=$(uci -q get firewall.@rule[$i].name 2>/dev/null)
    case "$name" in
        *Allow_LAN_to_IOT_Printer*|*Allow_LAN_to_IOT_mDNS*|*Allow_LAN_to_IOT_SNMP*|*Allow_LAN_to_IOT_ICMP*)
            echo "Eliminando regla existente: $name"
            uci -q delete firewall.@rule[$i]
            ;;
    esac
done

# Crear forwarding LAN -> IOT si no existe
exists=$(uci show firewall | grep -c "forwarding.*src='lan'.*dest='iot'")
if [ "$exists" -eq 0 ]; then
    sec=$(uci add firewall forwarding)
    uci set firewall.$sec.src='lan'
    uci set firewall.$sec.dest='iot'
    echo "Creado forwarding LAN -> IOT"
fi

# Crear reglas para impresora
# Puerto 9100 - JetDirect RAW
sec=$(uci add firewall rule)
uci set firewall.$sec.name='Allow_LAN_to_IOT_Printer_9100'
uci set firewall.$sec.src='lan'
uci set firewall.$sec.dest='iot'
uci set firewall.$sec.proto='tcp'
uci set firewall.$sec.dest_port='9100'
uci set firewall.$sec.target='ACCEPT'

# Puerto 515 - LPD
sec=$(uci add firewall rule)
uci set firewall.$sec.name='Allow_LAN_to_IOT_Printer_515'
uci set firewall.$sec.src='lan'
uci set firewall.$sec.dest='iot'
uci set firewall.$sec.proto='tcp'
uci set firewall.$sec.dest_port='515'
uci set firewall.$sec.target='ACCEPT'

# Puerto 631 - IPP
sec=$(uci add firewall rule)
uci set firewall.$sec.name='Allow_LAN_to_IOT_Printer_631'
uci set firewall.$sec.src='lan'
uci set firewall.$sec.dest='iot'
uci set firewall.$sec.proto='tcp'
uci set firewall.$sec.dest_port='631'
uci set firewall.$sec.target='ACCEPT'

# Puerto 445 - SMB
sec=$(uci add firewall rule)
uci set firewall.$sec.name='Allow_LAN_to_IOT_Printer_445'
uci set firewall.$sec.src='lan'
uci set firewall.$sec.dest='iot'
uci set firewall.$sec.proto='tcp'
uci set firewall.$sec.dest_port='445'
uci set firewall.$sec.target='ACCEPT'

# Puerto 139 - NetBIOS
sec=$(uci add firewall rule)
uci set firewall.$sec.name='Allow_LAN_to_IOT_Printer_139'
uci set firewall.$sec.src='lan'
uci set firewall.$sec.dest='iot'
uci set firewall.$sec.proto='tcp'
uci set firewall.$sec.dest_port='139'
uci set firewall.$sec.target='ACCEPT'

# mDNS/Bonjour - Puerto UDP 5353
sec=$(uci add firewall rule)
uci set firewall.$sec.name='Allow_LAN_to_IOT_mDNS'
uci set firewall.$sec.src='lan'
uci set firewall.$sec.dest='iot'
uci set firewall.$sec.proto='udp'
uci set firewall.$sec.dest_port='5353'
uci set firewall.$sec.target='ACCEPT'

# SNMP - Puerto UDP 161
sec=$(uci add firewall rule)
uci set firewall.$sec.name='Allow_LAN_to_IOT_SNMP'
uci set firewall.$sec.src='lan'
uci set firewall.$sec.dest='iot'
uci set firewall.$sec.proto='udp'
uci set firewall.$sec.dest_port='161'
uci set firewall.$sec.target='ACCEPT'

# ICMP - para ping y diagnóstico
sec=$(uci add firewall rule)
uci set firewall.$sec.name='Allow_LAN_to_IOT_ICMP'
uci set firewall.$sec.src='lan'
uci set firewall.$sec.dest='iot'
uci set firewall.$sec.proto='icmp'
uci set firewall.$sec.target='ACCEPT'

# Guardar configuración
uci commit firewall

# Recargar firewall
/etc/init.d/firewall reload

echo ""
echo "=== Configuración completada ==="
echo ""
echo "Reglas creadas:"
uci show firewall | grep -E "Allow_LAN_to_IOT"
echo ""
echo "Forwarding configurado:"
uci show firewall | grep -E "forwarding"