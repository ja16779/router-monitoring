#!/bin/sh

# Verifica que las interfaces definidas en mwan3 estén siendo monitoreadas (tracking)

echo "Verificando interfaces en seguimiento (tracking) de mwan3..."
echo "------------------------------------------------------------"

# Obtener las interfaces definidas en mwan3
interfaces=$(uci show mwan3 | grep mwan3.wan | cut -d'[' -f2 | cut -d']' -f1)

# Para cada interfaz habilitada
for i in $interfaces; do
    name=$(uci get mwan3.@interface[$i].interface)
    
    # Obtener estado de la interfaz desde mwan3
    status=$(ubus call mwan3 status | jsonfilter -e "@.interface_status.$name.status")

    if [ -z "$status" ]; then
        echo "⚠️  La interfaz '$name' no aparece en el estado de mwan3. ¿Está mal configurada?"
    else
        echo "Interfaz: $name - Estado: $status"
        if [ "$status" != "online" ]; then
            echo "⚠️  Advertencia: La interfaz '$name' no está online (estado: $status)"
        fi
    fi
done
