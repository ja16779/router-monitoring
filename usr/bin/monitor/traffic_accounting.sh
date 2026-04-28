#!/bin/sh
# Sistema de contabilidad de tráfico por cliente usando iptables

CHAIN_DOWN="TRAFFIC_DOWN"
CHAIN_UP="TRAFFIC_UP"
DATA_FILE="/tmp/traffic_clients.dat"

init_chains() {
    # Crear cadenas si no existen
    iptables -N $CHAIN_DOWN 2>/dev/null
    iptables -N $CHAIN_UP 2>/dev/null
    
    # Insertar en FORWARD si no está
    iptables -C FORWARD -j $CHAIN_DOWN 2>/dev/null || iptables -I FORWARD -j $CHAIN_DOWN
    iptables -C FORWARD -j $CHAIN_UP 2>/dev/null || iptables -I FORWARD -j $CHAIN_UP
}

update_rules() {
    # Obtener IPs activas de DHCP
    for ip in $(cat /tmp/dhcp.leases | awk '{print $3}'); do
        # Regla de descarga (destino es el cliente)
        iptables -C $CHAIN_DOWN -d $ip -j RETURN 2>/dev/null ||             iptables -A $CHAIN_DOWN -d $ip -j RETURN
        
        # Regla de subida (origen es el cliente)
        iptables -C $CHAIN_UP -s $ip -j RETURN 2>/dev/null ||             iptables -A $CHAIN_UP -s $ip -j RETURN
    done
}

get_traffic() {
    echo "# IP|DOWNLOAD_BYTES|UPLOAD_BYTES|HOSTNAME" > $DATA_FILE
    
    # Leer contadores de descarga
    iptables -L $CHAIN_DOWN -v -n -x 2>/dev/null | grep -E '^[[:space:]]*[0-9]' | while read pkts bytes target prot opt in out src dst rest; do
        [ -z "$dst" ] && continue
        [ "$dst" = "0.0.0.0/0" ] && continue
        
        # Obtener hostname
        hostname=$(grep "$dst" /tmp/dhcp.leases 2>/dev/null | awk '{print $4}' | head -1)
        [ -z "$hostname" ] || [ "$hostname" = "*" ] && hostname="-"
        
        # Obtener upload para esta IP
        upload=$(iptables -L $CHAIN_UP -v -n -x 2>/dev/null | grep " $dst " | awk '{print $2}' | head -1)
        [ -z "$upload" ] && upload=0
        
        echo "$dst|$bytes|$upload|$hostname"
    done >> $DATA_FILE
}

reset_counters() {
    iptables -Z $CHAIN_DOWN 2>/dev/null
    iptables -Z $CHAIN_UP 2>/dev/null
}

case "$1" in
    init)
        init_chains
        update_rules
        echo "Cadenas inicializadas"
        ;;
    update)
        update_rules
        echo "Reglas actualizadas"
        ;;
    get)
        get_traffic
        cat $DATA_FILE
        ;;
    reset)
        reset_counters
        echo "Contadores reiniciados"
        ;;
    *)
        echo "Uso: $0 {init|update|get|reset}"
        ;;
esac
