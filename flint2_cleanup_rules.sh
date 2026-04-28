#!/bin/sh
# Script de limpieza - elimina TODAS las reglas de impresora duplicadas
# y deja solo un conjunto limpio

echo "=== Limpiando reglas de impresora duplicadas ==="

# Eliminar TODAS las reglas existentes de impresora (tanto viejas como nuevas)
# Usando un bucle para encontrar todas las reglas por nombre
for i in $(seq 0 50); do
    name=$(uci -q get firewall.@rule[$i].name 2>/dev/null)
    case "$name" in
        *"Allow_LAN_to_IOT"*|*"Allow-LAN-to-IOT"*)
            echo "Eliminando regla $i: $name"
            uci -q delete firewall.@rule[$i]
            ;;
    esac
done

# Ahora crear reglas limpias y correctas
echo ""
echo "=== Creando reglas limpias ==="

# Puerto 9100 - JetDirect RAW
sec1=$(uci add firewall rule)
uci set firewall.$sec1.name='Allow_LAN_to_IOT_Printer_9100'
uci set firewall.$sec1.src='lan'
uci set firewall.$sec1.dest='iot'
uci set firewall.$sec1.proto='tcp'
uci set firewall.$sec1.dest_port='9100'
uci set firewall.$sec1.target='ACCEPT'

# Puerto 515 - LPD
sec2=$(uci add firewall rule)
uci set firewall.$sec2.name='Allow_LAN_to_IOT_Printer_515'
uci set firewall.$sec2.src='lan'
uci set firewall.$sec2.dest='iot'
uci set firewall.$sec2.proto='tcp'
uci set firewall.$sec2.dest_port='515'
uci set firewall.$sec2.target='ACCEPT'

# Puerto 631 - IPP
sec3=$(uci add firewall rule)
uci set firewall.$sec3.name='Allow_LAN_to_IOT_Printer_631'
uci set firewall.$sec3.src='lan'
uci set firewall.$sec3.dest='iot'
uci set firewall.$sec3.proto='tcp'
uci set firewall.$sec3.dest_port='631'
uci set firewall.$sec3.target='ACCEPT'

# Puerto 445 - SMB
sec4=$(uci add firewall rule)
uci set firewall.$sec4.name='Allow_LAN_to_IOT_Printer_445'
uci set firewall.$sec4.src='lan'
uci set firewall.$sec4.dest='iot'
uci set firewall.$sec4.proto='tcp'
uci set firewall.$sec4.dest_port='445'
uci set firewall.$sec4.target='ACCEPT'

# Puerto 139 - NetBIOS
sec5=$(uci add firewall rule)
uci set firewall.$sec5.name='Allow_LAN_to_IOT_Printer_139'
uci set firewall.$sec5.src='lan'
uci set firewall.$sec5.dest='iot'
uci set firewall.$sec5.proto='tcp'
uci set firewall.$sec5.dest_port='139'
uci set firewall.$sec5.target='ACCEPT'

# Puerto UDP 5353 - mDNS/Bonjour
sec6=$(uci add firewall rule)
uci set firewall.$sec6.name='Allow_LAN_to_IOT_mDNS'
uci set firewall.$sec6.src='lan'
uci set firewall.$sec6.dest='iot'
uci set firewall.$sec6.proto='udp'
uci set firewall.$sec6.dest_port='5353'
uci set firewall.$sec6.target='ACCEPT'

# Puerto UDP 161 - SNMP
sec7=$(uci add firewall rule)
uci set firewall.$sec7.name='Allow_LAN_to_IOT_SNMP'
uci set firewall.$sec7.src='lan'
uci set firewall.$sec7.dest='iot'
uci set firewall.$sec7.proto='udp'
uci set firewall.$sec7.dest_port='161'
uci set firewall.$sec7.target='ACCEPT'

# ICMP para diagnóstico
sec8=$(uci add firewall rule)
uci set firewall.$sec8.name='Allow_LAN_to_IOT_ICMP'
uci set firewall.$sec8.src='lan'
uci set firewall.$sec8.dest='iot'
uci set firewall.$sec8.proto='icmp'
uci set firewall.$sec8.target='ACCEPT'

# Verificar y crear forwarding si no existe
if ! uci show firewall | grep -q "forwarding.*lan.*iot"; then
    echo "Creando forwarding LAN -> IOT"
    fwd=$(uci add firewall forwarding)
    uci set firewall.$fwd.src='lan'
    uci set firewall.$fwd.dest='iot'
fi

# Guardar y recargar
uci commit firewall
/etc/init.d/firewall reload

echo ""
echo "=== Configuracion completada ==="
echo ""
echo "Reglas configuradas:"
uci show firewall | grep -E 'Allow_LAN_to_IOT' | sort | uniq
echo ""
echo "Forwarding configurado:"
uci show firewall | grep -E "forwarding.*src='lan'.*dest='iot'"