#!/bin/bash
# router_github_sync.sh - Sync automático de scripts y configs de routers a GitHub
# Ejecutar diariamente via cron: 0 9 * * * /home/ja16779/Desktop/Claude/scripts/router_github_sync.sh

set -e

# Configuración
REPO_DIR="$HOME/Desktop/Claude/home-lab"
FLINT_IP="192.168.10.1"
BERYL_IP="192.168.10.2"
ROUTER_USER="root"
ROUTER_PASS="admin"

LOG_FILE="/tmp/router_sync_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
    exit 1
}

log "=== Iniciando sync de routers a GitHub ==="

# Verificar que el repo existe
if [ ! -d "$REPO_DIR" ]; then
    error "Repo no encontrado en $REPO_DIR. Ejecuta primero: gh repo clone home-lab-config"
fi

cd "$REPO_DIR" || error "No se puede acceder a $REPO_DIR"

# Hacer pull para estar actualizado
log "Git pull..."
git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || log "Aviso: no se pudo hacer pull"

# ============================================
# FLINT-2
# ============================================

log "Descargando scripts de Flint-2..."
mkdir -p "routers/flint-2/scripts"
mkdir -p "routers/flint-2/config"
mkdir -p "routers/flint-2/templates"

# Scripts
sshpass -p "$ROUTER_PASS" ssh -o StrictHostKeyChecking=no "root@$FLINT_IP" \
    "tar czf - -C /usr/bin/monitor ." 2>/dev/null | tar xzf - -C "routers/flint-2/scripts" 2>/dev/null || \
    log "Aviso: no se pudieron descargar scripts de Flint-2"

# Configs no-sensibles
sshpass -p "$ROUTER_PASS" scp -o StrictHostKeyChecking=no \
    "root@$FLINT_IP:/etc/config/mwan3" "routers/flint-2/config/" 2>/dev/null || log "mwan3 no encontrado"

sshpass -p "$ROUTER_PASS" scp -o StrictHostKeyChecking=no \
    "root@$FLINT_IP:/etc/config/firewall" "routers/flint-2/config/" 2>/dev/null || log "firewall no encontrado"

sshpass -p "$ROUTER_PASS" scp -o StrictHostKeyChecking=no \
    "root@$FLINT_IP:/etc/config/nlbwmon" "routers/flint-2/config/" 2>/dev/null || log "nlbwmon no encontrado"

sshpass -p "$ROUTER_PASS" scp -o StrictHostKeyChecking=no \
    "root@$FLINT_IP:/etc/monitor/wifi_whitelist.conf" "routers/flint-2/config/" 2>/dev/null || log "wifi_whitelist no encontrado"

# Unbound configs
sshpass -p "$ROUTER_PASS" ssh -o StrictHostKeyChecking=no "root@$FLINT_IP" \
    "tar czf - -C /etc/unbound ." 2>/dev/null | tar xzf - -C "routers/flint-2/config/unbound" 2>/dev/null || \
    mkdir -p "routers/flint-2/config/unbound" && log "Aviso: no se pudieron descargar configs de unbound"

log "Flint-2 completado"

# ============================================
# BERYL
# ============================================

log "Descargando scripts de Beryl..."
mkdir -p "routers/beryl/scripts"
mkdir -p "routers/beryl/config"
mkdir -p "routers/beryl/templates"

# Scripts
sshpass -p "$ROUTER_PASS" ssh -o StrictHostKeyChecking=no "root@$BERYL_IP" \
    "tar czf - -C /usr/bin/monitor ." 2>/dev/null | tar xzf - -C "routers/beryl/scripts" 2>/dev/null || \
    log "Aviso: no se pudieron descargar scripts de Beryl"

# Configs no-sensibles
sshpass -p "$ROUTER_PASS" scp -o StrictHostKeyChecking=no \
    "root@$BERYL_IP:/etc/config/nlbwmon" "routers/beryl/config/" 2>/dev/null || log "nlbwmon no encontrado en Beryl"

sshpass -p "$ROUTER_PASS" scp -o StrictHostKeyChecking=no \
    "root@$BERYL_IP:/etc/monitor/wifi_whitelist.conf" "routers/beryl/config/" 2>/dev/null || log "wifi_whitelist no encontrado en Beryl"

log "Beryl completado"

# ============================================
# LIMPIEZA DE CREDENCIALES
# ============================================

log "Limpiando credenciales sensibles..."

# Remover tokens y passwords de todos los archivos
find "routers/" -type f -name "*.sh" -exec sed -i \
    -e 's/TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN=""/' \
    -e 's/TELEGRAM_CHAT_ID=.*/TELEGRAM_CHAT_ID=""/' \
    -e 's/password.*/password ""/' \
    -e 's/option key .*/option key ""/' \
    {} \; 2>/dev/null || true

# Crear config.sh.example para Flint-2
if [ ! -f "routers/flint-2/templates/config.sh.example" ]; then
    sshpass -p "$ROUTER_PASS" scp -o StrictHostKeyChecking=no \
        "root@$FLINT_IP:/etc/monitor/config.sh" "routers/flint-2/templates/config.sh.example" 2>/dev/null || true

    # Limpiar credenciales del ejemplo
    sed -i \
        -e 's/TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"/' \
        -e 's/TELEGRAM_CHAT_ID=.*/TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"/' \
        "routers/flint-2/templates/config.sh.example" 2>/dev/null || true
fi

# Crear config.sh.example para Beryl
if [ ! -f "routers/beryl/templates/config.sh.example" ]; then
    sshpass -p "$ROUTER_PASS" scp -o StrictHostKeyChecking=no \
        "root@$BERYL_IP:/etc/monitor/config.sh" "routers/beryl/templates/config.sh.example" 2>/dev/null || true

    # Limpiar credenciales del ejemplo
    sed -i \
        -e 's/TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"/' \
        -e 's/TELEGRAM_CHAT_ID=.*/TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"/' \
        "routers/beryl/templates/config.sh.example" 2>/dev/null || true
fi

# ============================================
# GIT COMMIT Y PUSH
# ============================================

log "Preparando commit..."

# Asegurarse de que .gitignore tiene las exclusiones
cat >> .gitignore << 'GITIGNORE'

# Credenciales - nunca subir
routers/*/config/config.sh
routers/*/templates/config.sh
routers/*/config/wireless
routers/*/**/*password*
routers/*/**/*secret*
routers/*/**/*token*
GITIGNORE

# Agregar cambios
git add routers/ .gitignore 2>/dev/null || true

# Verificar si hay cambios
if git diff --cached --quiet; then
    log "Sin cambios para commit"
else
    log "Haciendo commit..."
    git commit -m "sync: routers config y scripts - $(date '+%Y-%m-%d %H:%M')" || log "Aviso: commit falló"

    log "Haciendo push a GitHub..."
    git push origin main 2>/dev/null || git push origin master 2>/dev/null || error "Push falló"
fi

log "=== Sync completado exitosamente ==="
log "Log guardado en: $LOG_FILE"
