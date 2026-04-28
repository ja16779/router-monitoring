#!/bin/sh
# Script para verificar actualizaciones de firmware GL.iNet
# Consulta el foro de GL.iNet para detectar nuevas versiones

LOGTAG="glinet-check"
STATE_FILE="/tmp/glinet_version.txt"
CURRENT_VERSION="4.8.3"
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID="716542586"

# Detectar configuracion segun router
DEVICE=""
case "$(uname -n)" in
    GL-MT6000)
        TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
        DEVICE="MT6000"
        SEARCH_TERM="MT6000\|Flint.2"
        ;;
    GL-MT3000*)
        TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
        DEVICE="MT3000"
        SEARCH_TERM="MT3000\|Beryl"
        ;;
esac

# Enviar mensaje a Telegram
send_telegram() {
    local message="$1"

    logger -p local0.info -t "$LOGTAG" "$message"

    [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] && return

    curl -skim 10 \
        --data disable_notification="false" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$message" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

# Obtener ultima version del foro GL.iNet
get_latest_version() {
    # Buscar en el RSS del foro menciones de versiones de firmware
    local rss_content
    rss_content="$(curl -sk --max-time 20 'https://forum.gl-inet.com/latest.rss' 2>/dev/null)"

    # Extraer versiones que coincidan con el patron v4.X.X
    echo "$rss_content" | grep -iE "$SEARCH_TERM" | \
        grep -oE 'v?4\.[0-9]+\.[0-9]+' | \
        sed 's/^v//' | \
        sort -t. -k1,1n -k2,2n -k3,3n | \
        uniq | tail -1
}

# Comparar versiones (retorna 0 si v1 < v2)
version_lt() {
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -1)" = "$1" ] && [ "$1" != "$2" ]
}

# Main
LATEST_VERSION="$(get_latest_version)"
TIMESTAMP="$(date '+%A %d-%b-%Y %T')"

# Si no obtuvimos version del foro, usar la conocida
[ -z "$LATEST_VERSION" ] && LATEST_VERSION="4.8.3"

# Leer version anterior notificada
PREV_NOTIFIED=""
[ -f "$STATE_FILE" ] && PREV_NOTIFIED="$(cat "$STATE_FILE")"

logger -t "$LOGTAG" "Version actual: $CURRENT_VERSION, Ultima en foro: $LATEST_VERSION"

# Comparar versiones
if version_lt "$CURRENT_VERSION" "$LATEST_VERSION"; then
    # Solo notificar si es una version nueva
    if [ "$LATEST_VERSION" != "$PREV_NOTIFIED" ]; then
        send_telegram "<b>Nueva version GL.iNet disponible</b>
<pre>
Router: $(uname -n)
Modelo: $DEVICE
Time: ${TIMESTAMP}
Version actual: ${CURRENT_VERSION}
Nueva version: ${LATEST_VERSION}
</pre>
Descarga: https://dl.gl-inet.com/router/${DEVICE,,}/"

        echo "$LATEST_VERSION" > "$STATE_FILE"
    fi
else
    logger -t "$LOGTAG" "Firmware GL.iNet actualizado"
fi

# Tambien buscar menciones de releases estables en el foro
STABLE_RELEASE="$(curl -sk --max-time 20 'https://forum.gl-inet.com/latest.rss' 2>/dev/null | \
    grep -i 'stable.release' | grep -iE "$SEARCH_TERM" | head -1)"

if [ -n "$STABLE_RELEASE" ]; then
    NEW_VER="$(echo "$STABLE_RELEASE" | grep -oE 'v?4\.[0-9]+\.[0-9]+' | sed 's/^v//' | head -1)"
    if [ -n "$NEW_VER" ] && version_lt "$CURRENT_VERSION" "$NEW_VER"; then
        if [ "$NEW_VER" != "$PREV_NOTIFIED" ]; then
            send_telegram "<b>Release estable GL.iNet detectado</b>
<pre>
Router: $(uname -n)
Version: ${NEW_VER}
</pre>"
            echo "$NEW_VER" > "$STATE_FILE"
        fi
    fi
fi
