#!/bin/sh
# update_adguardhome.sh - Actualiza AdGuard Home al último release oficial
# Uso: update_adguardhome.sh [--check] [--force] [notify]
#   --check   Solo verificar si hay actualización (sin instalar)
#   --force   Instalar aunque la versión sea igual
#   notify    Enviar resultado a Telegram

. /etc/monitor/config.sh 2>/dev/null

AGH_BIN="/usr/bin/AdGuardHome"
AGH_ARCH="arm64"   # aarch64
TEMP_DIR="/tmp/agh_update_$$"
API_URL="https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest"

CHECK_ONLY=""
FORCE=""
NOTIFY=""
for arg in "$@"; do
    case "$arg" in
        --check) CHECK_ONLY=1 ;;
        --force) FORCE=1 ;;
        notify)  NOTIFY=1 ;;
    esac
done

log() { logger -t "agh-update" "$*"; echo "$*"; }

notify_telegram() {
    [ "${TELEGRAM_ACTIVO:-0}" -ne 1 ] && return
    curl -s -X POST --connect-timeout 10 \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=$1" \
        -d "parse_mode=HTML" \
        -d "disable_notification=true" >/dev/null 2>&1
}

# Obtener versión actual
CURRENT=$(${AGH_BIN} --version 2>/dev/null | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
if [ -z "$CURRENT" ]; then
    log "ERROR: No se pudo obtener la versión actual de AdGuard Home"
    exit 1
fi

log "Versión actual: $CURRENT"

# Obtener última versión via GitHub API
API_RESP=$(curl -sf --connect-timeout 15 --max-time 30 "$API_URL" 2>/dev/null)
if [ -z "$API_RESP" ]; then
    log "ERROR: No se pudo contactar GitHub API"
    [ -n "$NOTIFY" ] && notify_telegram "AdGuard Home: ERROR consultando GitHub API"
    exit 1
fi

LATEST=$(printf '%s' "$API_RESP" | grep '"tag_name"' | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | tr -d 'v')
if [ -z "$LATEST" ]; then
    log "ERROR: No se pudo parsear la versión desde GitHub"
    exit 1
fi

log "Última versión disponible: $LATEST"

# Comparar versiones
if [ "$CURRENT" = "$LATEST" ] && [ -z "$FORCE" ]; then
    log "Ya tienes la versión más reciente ($CURRENT)"
    [ -n "$NOTIFY" ] && notify_telegram "<b>AdGuard Home</b>: ya en versión más reciente (v${CURRENT})"
    exit 0
fi

if [ -n "$CHECK_ONLY" ]; then
    log "Actualización disponible: $CURRENT -> $LATEST"
    [ -n "$NOTIFY" ] && notify_telegram "<b>AdGuard Home</b>: actualización disponible
Actual: v${CURRENT}
Nueva:  v${LATEST}"
    exit 0
fi

# === DESCARGAR Y ACTUALIZAR ===
log "Iniciando actualización: $CURRENT -> $LATEST"

# Verificar espacio (binario ~35MB, necesitamos ~100MB en /tmp)
FREE_TMP=$(df /tmp | awk 'NR==2 {print $4}')
if [ "${FREE_TMP:-0}" -lt 102400 ]; then
    log "ERROR: Espacio insuficiente en /tmp (${FREE_TMP}KB disponibles, se necesitan 100MB)"
    exit 1
fi

mkdir -p "$TEMP_DIR"
TARBALL="${TEMP_DIR}/AdGuardHome_linux_${AGH_ARCH}.tar.gz"
CHECKSUM_FILE="${TEMP_DIR}/checksums.txt"
DOWNLOAD_BASE="https://github.com/AdguardTeam/AdGuardHome/releases/download/v${LATEST}"

log "Descargando AdGuardHome v${LATEST} (${AGH_ARCH})..."
if ! curl -L --connect-timeout 30 --max-time 300 --retry 2 \
    "${DOWNLOAD_BASE}/AdGuardHome_linux_${AGH_ARCH}.tar.gz" \
    -o "$TARBALL" 2>/dev/null; then
    log "ERROR: Descarga fallida"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Verificar checksum SHA256
log "Verificando checksum..."
curl -sf --connect-timeout 15 "${DOWNLOAD_BASE}/checksums.txt" -o "$CHECKSUM_FILE" 2>/dev/null
if [ -f "$CHECKSUM_FILE" ]; then
    EXPECTED=$(grep "AdGuardHome_linux_${AGH_ARCH}.tar.gz" "$CHECKSUM_FILE" | awk '{print $1}')
    ACTUAL=$(sha256sum "$TARBALL" 2>/dev/null | awk '{print $1}')
    if [ -n "$EXPECTED" ] && [ "$EXPECTED" != "$ACTUAL" ]; then
        log "ERROR: Checksum no coincide. Abortando."
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    log "Checksum OK"
else
    log "AVISO: No se pudo verificar checksum (continuando)"
fi

# Extraer binario (el tar usa ./AdGuardHome/AdGuardHome)
log "Extrayendo..."
if ! tar -xzf "$TARBALL" -C "$TEMP_DIR" 2>/dev/null; then
    log "ERROR: Extracción fallida"
    rm -rf "$TEMP_DIR"
    exit 1
fi

NEW_BIN=$(find "$TEMP_DIR" -name "AdGuardHome" -type f ! -name "*.sig" | head -1)
if [ ! -x "$NEW_BIN" ]; then
    log "ERROR: Binario extraído no es ejecutable"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Verificar que el binario nuevo reporta la versión esperada
NEW_VER=$(${NEW_BIN} --version 2>/dev/null | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
if [ "$NEW_VER" != "$LATEST" ]; then
    log "ERROR: Binario descargado reporta versión '$NEW_VER', esperada '$LATEST'"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Backup del binario actual
cp "${AGH_BIN}" "${AGH_BIN}.bak" 2>/dev/null
log "Backup guardado en ${AGH_BIN}.bak"

# Parar servicio
log "Deteniendo AdGuard Home..."
/etc/init.d/adguardhome stop 2>/dev/null
sleep 3

# Reemplazar binario
if ! cp "$NEW_BIN" "$AGH_BIN"; then
    log "ERROR: No se pudo copiar el nuevo binario. Restaurando backup..."
    cp "${AGH_BIN}.bak" "$AGH_BIN"
    /etc/init.d/adguardhome start 2>/dev/null
    rm -rf "$TEMP_DIR"
    exit 1
fi
chmod 755 "$AGH_BIN"

# Iniciar servicio
log "Iniciando AdGuard Home..."
/etc/init.d/adguardhome start 2>/dev/null
sleep 5

# Verificar que arrancó correctamente
RUNNING=$(ps | grep AdGuardHome | grep -v grep | wc -l)
FINAL_VER=$(${AGH_BIN} --version 2>/dev/null | grep -o '[0-9]*\.[0-9]*\.[0-9]*')

if [ "$RUNNING" -gt 0 ] && [ "$FINAL_VER" = "$LATEST" ]; then
    log "Actualización exitosa: $CURRENT -> $FINAL_VER"
    rm -f "${AGH_BIN}.bak"
    [ -n "$NOTIFY" ] && notify_telegram "<b>AdGuard Home actualizado</b>
v${CURRENT} -> v${FINAL_VER}"
else
    log "ERROR: El servicio no arrancó correctamente. Restaurando backup..."
    /etc/init.d/adguardhome stop 2>/dev/null
    cp "${AGH_BIN}.bak" "$AGH_BIN"
    chmod 755 "$AGH_BIN"
    /etc/init.d/adguardhome start 2>/dev/null
    [ -n "$NOTIFY" ] && notify_telegram "<b>AdGuard Home: ERROR en actualización</b>
Restaurado a v${CURRENT}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

rm -rf "$TEMP_DIR"
