#!/bin/sh
# Script para limpiar y configurar correctamente el firewall para impresora IOT

echo "=== LIMPIEZA DE REGLAS DUPLICADAS ==="

# Eliminar forwarding duplicados LAN->IOT (solo debe quedar uno)
for i in 7 6; do
    uci -q delete firewall.@forwarding[$i] 2>/dev/null
done

# Encontrar y eliminar reglas duplicadas de impresora
# Primero obtener lista de índices de reglas con nombres duplicados
echo "Buscando reglas duplicadas..."

# Eliminar reglas antiguas con formato incorrecto (con guiones)
for i in $(seq 0 40); do
    name=$(uci -q get firewall.@rule[$i].name 2>/dev/null)
    case "$name" in
        *"Allow-LAN-to-IOT"*)
            echo "Eliminando regla con formato antiguo [$i]: $name"
            uci -q delete firewall.@rule[$i]
            ;;
    esac
done

# Ahora verificar duplicados en las reglas nuevas (con guiones bajos)
# y eliminar las primeras ocurrencias (mantener las últimas)
echo "Verificando duplicados en reglas nuevas..."

# Guardar configuración
uci commit firewall

echo ""
echo "=== CONFIGURACIÓN ACTUAL ==="
echo "Forwardings LAN<->IOT:"
uci show firewall | grep -E "forwarding.*src.*'(lan|iot)'.*dest.*'(lan|iot)'"

echo ""
echo "Reglas de impresora:"
uci show firewall | grep "Allow_LAN_to_IOT"

echo ""
echo "Total reglas Allow_LAN_to_IOT: $(uci show firewall | grep -c 'Allow_LAN_to_IOT')"

echo ""
echo "=== RECARGANDO FIREWALL ==="
/etc/init.d/firewall reload 2>&1

echo ""
echo "=== VERIFICACIÓN IPTABLES ==="
iptables -L FORWARD -n | grep -E "9100|515|631|445|139|5353|161|icmp" | head -20

echo ""
echo "Listo!"