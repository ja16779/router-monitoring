#!/bin/sh
# pkg_updater.sh - Verifica e instala actualizaciones de paquetes OpenWrt (apk)
# Uso: pkg_updater.sh [check|upgrade]
#   check   - Solo verificar y notificar (default)
#   upgrade - Instalar actualizaciones seguras + notificar

. /etc/monitor/config.sh 2>/dev/null || {
    TELEGRAM_BOT_TOKEN="REDACTED_BOT_TOKEN"
    TELEGRAM_CHAT_ID="716542586"
}

LOGTAG="pkg-updater"
HOSTNAME=$(uname -n)
FECHA=$(date "+%Y-%m-%d %H:%M")
MODE="${1:-check}"
TMP_SIM="/tmp/pkg_simulate.txt"

# ── utilidades ──────────────────────────────────────────────────

log() { logger -t "$LOGTAG" "$1"; }

send_telegram() {
    [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && return
    curl -skim 10 \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$1" \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" >/dev/null 2>&1
}

is_unsafe() {
    case "$1" in
        kmod-*|kernel*|libc|musl*|procd*|netifd*|base-files*) return 0 ;;
        *) return 1 ;;
    esac
}

# ── actualizar índice ────────────────────────────────────────────

log "Actualizando indice de paquetes..."
UPDATE_OUT=$(apk update 2>&1)
if ! echo "$UPDATE_OUT" | grep -q "^OK:"; then
    log "ERROR: fallo al actualizar indice"
    send_telegram "⚠️ <b>pkg-updater</b> | $HOSTNAME
Error actualizando índice de paquetes apk."
    exit 1
fi

# ── obtener lista de actualizables ───────────────────────────────

apk upgrade --simulate 2>/dev/null | grep "^(" > "$TMP_SIM"
TOTAL=$(wc -l < "$TMP_SIM" | tr -d ' ')

if [ "$TOTAL" -eq 0 ]; then
    log "Sin actualizaciones disponibles"
    rm -f "$TMP_SIM"
    exit 0
fi

# Clasificar en seguros / peligrosos
SAFE_LIST=""
UNSAFE_LIST=""
while read -r line; do
    pkg=$(echo "$line" | sed 's/.*Upgrading \([^ ]*\) .*/\1/')
    if is_unsafe "$pkg"; then
        UNSAFE_LIST="${UNSAFE_LIST}  ⚠ ${line}
"
    else
        SAFE_LIST="${SAFE_LIST}  ${line}
"
    fi
done < "$TMP_SIM"
rm -f "$TMP_SIM"

SAFE_COUNT=$(echo "$SAFE_LIST" | grep "Upgrading" | wc -l | tr -d ' ')
UNSAFE_COUNT=$(echo "$UNSAFE_LIST" | grep "Upgrading" | wc -l | tr -d ' ')

log "$TOTAL paquetes actualizables: $SAFE_COUNT seguros, $UNSAFE_COUNT requieren revision"

# ── modo CHECK: solo notificar ───────────────────────────────────

if [ "$MODE" = "check" ]; then
    PKG_LINES=$(echo "$SAFE_LIST$UNSAFE_LIST" | grep "Upgrading" | \
        sed 's/.*Upgrading \([^ ]*\) (\(.*\) -> \(.*\))/  * \1  \2 -> \3/' | head -30)

    EXTRA=""
    [ "$TOTAL" -gt 30 ] && EXTRA="  ... y $((TOTAL - 30)) mas"

    MSG="📦 <b>Actualizaciones disponibles</b>
<code>━━━━━━━━━━━━━━━━━━━━</code>
🏠 $HOSTNAME | $FECHA

📊 Total: <b>$TOTAL</b>  ✅ Seguros: <b>$SAFE_COUNT</b>"

    [ "$UNSAFE_COUNT" -gt 0 ] && MSG="$MSG  ⚠️ Revisar: <b>$UNSAFE_COUNT</b>"

    MSG="$MSG
<code>━━━━━━━━━━━━━━━━━━━━</code>
<pre>$PKG_LINES$EXTRA</pre>
Ejecutar con <code>upgrade</code> para instalar"

    send_telegram "$MSG"
    exit 0
fi

# ── modo UPGRADE: instalar paquetes seguros ──────────────────────

if [ "$MODE" = "upgrade" ]; then
    if [ "$SAFE_COUNT" -eq 0 ]; then
        log "No hay paquetes seguros para instalar"
        [ "$UNSAFE_COUNT" -gt 0 ] && send_telegram \
            "⚠️ <b>pkg-updater</b> | $HOSTNAME
Hay $UNSAFE_COUNT paquetes que requieren revision manual:
<pre>$UNSAFE_LIST</pre>"
        exit 0
    fi

    log "Instalando $SAFE_COUNT actualizaciones..."

    # Obtener nombres de paquetes seguros
    SAFE_PKGS=$(echo "$SAFE_LIST" | grep "Upgrading" | sed 's/.*Upgrading \([^ ]*\) .*/\1/' | tr '\n' ' ')

    UPGRADE_OUT=$(apk upgrade $SAFE_PKGS 2>&1)
    EXIT_CODE=$?
    ERRORS=$(echo "$UPGRADE_OUT" | grep -i "error\|fail" | head -5)

    if [ "$EXIT_CODE" -eq 0 ]; then
        log "Actualizacion completada: $SAFE_COUNT paquetes instalados"
        ICON="✅"
        STATUS="Actualizacion completada"
    else
        log "Actualizacion con errores (exit $EXIT_CODE)"
        ICON="⚠️"
        STATUS="Completado con errores"
    fi

    PKG_LINES=$(echo "$SAFE_LIST" | grep "Upgrading" | \
        sed 's/.*Upgrading \([^ ]*\) (\(.*\) -> \(.*\))/  * \1  \2 -> \3/' | head -25)

    MSG="$ICON <b>$STATUS</b>
<code>━━━━━━━━━━━━━━━━━━━━</code>
🏠 $HOSTNAME | $FECHA

✅ Instalados: <b>$SAFE_COUNT</b>"

    [ "$UNSAFE_COUNT" -gt 0 ] && MSG="$MSG
⚠️ Omitidos (revision manual): <b>$UNSAFE_COUNT</b>
<pre>$UNSAFE_LIST</pre>"

    MSG="$MSG
<code>━━━━━━━━━━━━━━━━━━━━</code>
<pre>$PKG_LINES</pre>"

    [ -n "$ERRORS" ] && MSG="$MSG
❌ <b>Errores:</b>
<pre>$ERRORS</pre>"

    send_telegram "$MSG"

    # Refrescar índice post-instalación
    apk update >/dev/null 2>&1

    exit $EXIT_CODE
fi

echo "Uso: $0 [check|upgrade]"
echo "  check   - Verificar y notificar (default)"
echo "  upgrade - Instalar actualizaciones seguras"
exit 1
