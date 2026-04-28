#!/bin/sh
# =============================================================================
# Script: iot_printer_access.sh
# Descripción: Configura reglas de firewall para permitir impresión desde
#              VLAN LAN (192.168.10.x) hacia VLAN IOT (192.168.8.x)
#              donde se encuentra la impresora Samsung.
#
# Uso: ./iot_printer_access.sh [aplicar|revertir|status]
#      - Sin argumentos: muestra configuración propuesta
#      - aplicar: aplica las reglas de firewall
#      - revertir: elimina las reglas
#      - status: muestra estado actual
# =============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Puertos necesarios para impresión
PRINTER_PORTS_TCP="9100 515 631 445 139 80 443"
PRINTER_PORTS_UDP="161 162 137 138 5353 427"

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar si estamos en OpenWrt
check_openwrt() {
    if [ ! -f /etc/openwrt_release ]; then
        log_error "Este script debe ejecutarse en un router OpenWrt"
        exit 1
    fi
    
    log_ok "OpenWrt detectado: $(cat /etc/openwrt_release | grep DISTRIB_DESCRIPTION | cut -d= -f2 | tr -d '\"')"
}

# Obtener nombre de la zona LAN/IOT
get_zone_name() {
    local zone=$(uci get firewall.@zone[0].name 2>/dev/null || echo "lan")
    echo "$zone"
}

# Mostrar configuración propuesta
show_config() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║     CONFIGURACIÓN PARA ACCESO A IMPRESORA IOT DESDE LAN         ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Redes configuradas:"
    echo "  🔸 LAN:  192.168.10.x (donde están los clientes)"
    echo "  🔸 IOT:  192.168.8.x  (donde está la impresora Samsung)"
    echo ""
    echo "Puertos que se habilitarán para impresión:"
    echo "  📡 TCP: $PRINTER_PORTS_TCP"
    echo "  📡 UDP: $PRINTER_PORTS_UDP"
    echo ""
    echo "Descripción de puertos:"
    echo "  • 9100: JetDirect/RAW printing (HP, Samsung, etc.)"
    echo "  • 515:  LPD/LPR protocol"
    echo "  • 631:  IPP (Internet Printing Protocol)"
    echo "  • 445:  SMB/CIFS (Windows printer sharing)"
    echo "  • 139:  NetBIOS session (Windows)"
    echo "  • 161:  SNMP (printer discovery)"
    echo "  • 5353: mDNS/Bonjour discovery"
    echo ""
    echo "Reglas que se crearán:"
    echo "  1. Permitir forward desde LAN -> IOT (establecido)"
    echo "  2. Permitir tráfico NEW desde LAN -> IOT para impresión"
    echo "  3. Permitir respuestas DNS desde IOT -> LAN"
    echo ""
}

# Crear reglas de firewall para impresión
apply_rules() {
    log_info "Aplicando reglas de firewall para impresión IOT..."
    
    local zone=$(get_zone_name)
    log_info "Zona detectada: $zone"
    
    # Verificar si IOT está en la zona
    if ! uci get firewall.@zone[0].network 2>/dev/null | grep -q "IOT"; then
        log_warn "IOT no está en la zona $zone, agregando..."
        uci add_list firewall.@zone[0].network="IOT"
    fi
    
    # Habilitar forward en la zona (si no está habilitado)
    current_forward=$(uci get firewall.@zone[0].forward 2>/dev/null || echo "REJECT")
    if [ "$current_forward" = "REJECT" ]; then
        log_info "Habilitando forward en zona $zone..."
        uci set firewall.@zone[0].forward="ACCEPT"
    fi
    
    # Crear regla para permitir tráfico de impresión desde LAN a IOT
    
    # Primero, eliminar reglas anteriores si existen (para evitar duplicados)
    remove_rules_silent
    
    # Regla 1: Permitir tráfico TCP de impresión desde LAN a IOT
    log_info "Creando regla TCP para impresión..."
    local rule_tcp=$(uci add firewall rule)
    uci set firewall.$rule_tcp.name="Allow-LAN-to-IOT-Printer-TCP"
    uci set firewall.$rule_tcp.src="lan"
    uci set firewall.$rule_tcp.dest="iot"
    uci set firewall.$rule_tcp.proto="tcp"
    uci set firewall.$rule_tcp.dest_port="$(echo $PRINTER_PORTS_TCP | tr ' ' ',')"
    uci set firewall.$rule_tcp.target="ACCEPT"
    
    # Regla 2: Permitir tráfico UDP de impresión (descubrimiento, SNMP)
    log_info "Creando regla UDP para descubrimiento..."
    local rule_udp=$(uci add firewall rule)
    uci set firewall.$rule_udp.name="Allow-LAN-to-IOT-Printer-UDP"
    uci set firewall.$rule_udp.src="lan"
    uci set firewall.$rule_udp.dest="iot"
    uci set firewall.$rule_udp.proto="udp"
    uci set firewall.$rule_udp.dest_port="$(echo $PRINTER_PORTS_UDP | tr ' ' ',')"
    uci set firewall.$rule_udp.target="ACCEPT"
    
    # Regla 3: Permitir ping/discovery general
    log_info "Creando regla ICMP..."
    local rule_icmp=$(uci add firewall rule)
    uci set firewall.$rule_icmp.name="Allow-LAN-to-IOT-ICMP"
    uci set firewall.$rule_icmp.src="lan"
    uci set firewall.$rule_icmp.dest="iot"
    uci set firewall.$rule_icmp.proto="icmp"
    uci set firewall.$rule_icmp.target="ACCEPT"
    
    # Guardar cambios
    uci commit firewall
    
    # Recargar firewall
    log_info "Recargando firewall..."
    /etc/init.d/firewall reload
    
    log_ok "Reglas aplicadas exitosamente!"
    echo ""
    log_info "Puedes verificar con: iptables -L -n | grep -i printer"
}

# Eliminar reglas (versión silenciosa para re-aplicar)
remove_rules_silent() {
    # Obtener todas las secciones de firewall que coincidan
    local sections=$(uci show firewall | grep -E "Allow-LAN-to-IOT-Printer|Allow-LAN-to-IOT-ICMP" | cut -d= -f1 | sed 's/firewall\.//')
    
    for section in $sections; do
        uci -q delete firewall.$section 2>/dev/null || true
    done
}

# Eliminar reglas (versión verbose)
revert_rules() {
    log_info "Eliminando reglas de impresión IOT..."
    
    remove_rules_silent
    uci commit firewall
    /etc/init.d/firewall reload
    
    log_ok "Reglas eliminadas."
}

# Mostrar estado actual
show_status() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                   ESTADO ACTUAL DEL FIREWALL                      ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    echo "🔸 Zonas de firewall:"
    uci show firewall | grep -A5 "@zone\[0\]" | head -6
    echo ""
    
    echo "🔸 Reglas de impresión configuradas:"
    local rules=$(uci show firewall | grep -E "Allow-LAN-to-IOT-Printer|Allow-LAN-to-IOT-ICMP" || echo "Ninguna")
    echo "$rules"
    echo ""
    
    echo "🔸 Reglas activas en iptables:"
    iptables -L -n | grep -E "(Allow-LAN-to-IOT|9100|515|631)" || echo "No se encontraron reglas activas"
    echo ""
    
    echo "🔸 Conectividad entre redes:"
    echo "   LAN -> IOT: $(ping -c1 -W2 192.168.8.1 >/dev/null 2>&1 && echo "✅ OK" || echo "❌ No responde")"
    echo ""
}

# Menú de ayuda
show_help() {
    cat << 'EOF'
Uso: ./iot_printer_access.sh [comando]

Comandos disponibles:
  (vacío)    Muestra la configuración propuesta
  aplicar    Aplica las reglas de firewall
  revertir   Elimina las reglas de impresión
  status     Muestra el estado actual del firewall
  ayuda      Muestra esta ayuda

Ejemplos:
  ./iot_printer_access.sh              # Ver configuración
  ./iot_printer_access.sh aplicar     # Aplicar reglas
  ./iot_printer_access.sh revertir    # Eliminar reglas

EOF
}

# Script principal
main() {
    check_openwrt
    
    case "$1" in
        aplicar|apply)
            show_config
            echo ""
            read -p "¿Aplicar estas reglas? [s/N]: " confirm
            if [ "$confirm" = "s" ] || [ "$confirm" = "S" ]; then
                apply_rules
            else
                log_info "Operación cancelada."
            fi
            ;;
        revertir|remove|delete)
            read -p "¿Eliminar reglas de impresión? [s/N]: " confirm
            if [ "$confirm" = "s" ] || [ "$confirm" = "S" ]; then
                revert_rules
            else
                log_info "Operación cancelada."
            fi
            ;;
        status)
            show_status
            ;;
        ayuda|help|-h|--help)
            show_help
            ;;
        *)
            show_config
            echo ""
            echo "Para aplicar estas reglas, ejecuta: ./iot_printer_access.sh aplicar"
            echo "Para más opciones: ./iot_printer_access.sh ayuda"
            ;;
    esac
}

main "$@"