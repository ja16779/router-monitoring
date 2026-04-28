#!/bin/bash
# Script para instalar el exportador en routers OpenWrt
# Uso: ./install_exporter.sh <IP_ROUTER>

ROUTER_IP=${1:-192.168.10.1}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Instalando exportador en $ROUTER_IP ==="

# Copiar exportador
scp -o StrictHostKeyChecking=no "$SCRIPT_DIR/openwrt_exporter.sh" root@$ROUTER_IP:/usr/bin/
ssh -o StrictHostKeyChecking=no root@$ROUTER_IP "chmod +x /usr/bin/openwrt_exporter.sh"

# Copiar init script
scp -o StrictHostKeyChecking=no "$SCRIPT_DIR/openwrt_exporter_init" root@$ROUTER_IP:/etc/init.d/openwrt_exporter
ssh -o StrictHostKeyChecking=no root@$ROUTER_IP "chmod +x /etc/init.d/openwrt_exporter"

# Habilitar e iniciar servicio
ssh -o StrictHostKeyChecking=no root@$ROUTER_IP "/etc/init.d/openwrt_exporter enable && /etc/init.d/openwrt_exporter start"

# Verificar
echo "=== Verificando servicio ==="
ssh -o StrictHostKeyChecking=no root@$ROUTER_IP "netstat -tlnp | grep 9101"

echo "=== Listo! Exportador instalado en $ROUTER_IP:9101 ==="
