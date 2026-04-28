#!/bin/bash
# Script para diagnosticar Unbound en OpenWrt (Flint-2)

ROUTER_IP="192.168.10.1"
SSH_USER="root"
SSH_PASS="admin"

echo "=========================================="
echo "Diagnóstico de Unbound - Flint-2"
echo "=========================================="
echo ""

# Verificar si unbound está instalado
echo "--- Verificando instalación de Unbound ---"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${ROUTER_IP} "opkg list-installed | grep unbound"

echo ""
echo "--- Estado del servicio Unbound ---"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${ROUTER_IP} "/etc/init.d/unbound status"

echo ""
echo "--- Proceso Unbound ---"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${ROUTER_IP} "ps | grep unbound"

echo ""
echo "--- Puertos escuchando ---"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${ROUTER_IP} "netstat -tlnp | grep -E '53|unbound'"

echo ""
echo "--- Configuración de Unbound (/etc/unbound/unbound.conf) ---"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${ROUTER_IP} "cat /etc/unbound/unbound.conf 2>/dev/null || echo 'Archivo no encontrado'"

echo ""
echo "--- Configuración UCI de Unbound ---"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${ROUTER_IP} "uci show unbound 2>/dev/null || echo 'Config UCI no encontrada'"

echo ""
echo "--- Logs recientes de Unbound ---"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${ROUTER_IP} "logread -e unbound | tail -20"

echo ""
echo "--- Test de resolución DNS local ---"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${ROUTER_IP} "nslookup google.com 127.0.0.1"

echo ""
echo "--- Archivos de configuración adicionales ---"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${ROUTER_IP} "ls -la /etc/unbound/ 2>/dev/null || echo 'Directorio /etc/unbound/ no existe'"

echo ""
echo "--- Verificación de root-hints ---"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SSH_USER}@${ROUTER_IP} "ls -la /var/lib/unbound/ 2>/dev/null || echo 'Directorio /var/lib/unbound/ no existe'"

echo ""
echo "=========================================="
echo "Diagnóstico completado"
echo "=========================================="