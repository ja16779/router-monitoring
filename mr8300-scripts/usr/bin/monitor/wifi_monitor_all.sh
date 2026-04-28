#!/bin/sh
# WiFi Monitor - Monitorea canales de GL-MT6000 y Beryl
# Uso: wifi_monitor_all.sh [-v] [notify] [auto]

. /etc/monitor/config.sh 2>/dev/null

VERBOSE=""
NOTIFY=""
AUTO=""

for arg in "$@"; do
    case "$arg" in
        -v) VERBOSE=1 ;;
        notify) NOTIFY=1 ;;
        auto) AUTO=1 ;;
    esac
done

BERYL_IP="192.168.10.2"
BERYL_PASS="admin"

# Canales no solapados
CHANNELS_2G="1 6 11"
CHANNELS_5G="36 40 44 48 149 153 157 161"

HOSTNAME=$(uci get system.@system[0].hostname 2>/dev/null || echo "GL-MT6000")
FECHA=$(date "+%d/%m/%Y %H:%M")

# ========== GL-MT6000 ==========
get_channel_mt6000() {
    local iface="$1"
    iwinfo "$iface" info 2>/dev/null | grep "Channel:" | awk '{print $4}'
}

scan_count_mt6000() {
    local iface="$1"
    local channel="$2"
    iwinfo "$iface" scan 2>/dev/null | grep -c "Channel: $channel"
}

MT6000_2G_CH=$(get_channel_mt6000 "wlan0")
MT6000_5G_CH=$(get_channel_mt6000 "wlan1")

# Contar redes en canales actuales
MT6000_2G_COUNT=$(scan_count_mt6000 "wlan0" "$MT6000_2G_CH")
MT6000_5G_COUNT=$(scan_count_mt6000 "wlan1" "$MT6000_5G_CH")

# Encontrar mejor canal 2.4GHz MT6000
MT6000_2G_BEST="$MT6000_2G_CH"
MT6000_2G_BEST_COUNT=$MT6000_2G_COUNT
for ch in $CHANNELS_2G; do
    count=$(scan_count_mt6000 "wlan0" "$ch")
    if [ "$count" -lt "$MT6000_2G_BEST_COUNT" ]; then
        MT6000_2G_BEST="$ch"
        MT6000_2G_BEST_COUNT=$count
    fi
done

# Encontrar mejor canal 5GHz MT6000
MT6000_5G_BEST="$MT6000_5G_CH"
MT6000_5G_BEST_COUNT=$MT6000_5G_COUNT
for ch in $CHANNELS_5G; do
    count=$(scan_count_mt6000 "wlan1" "$ch")
    if [ "$count" -lt "$MT6000_5G_BEST_COUNT" ]; then
        MT6000_5G_BEST="$ch"
        MT6000_5G_BEST_COUNT=$count
    fi
done

# Status MT6000
if [ "$MT6000_2G_CH" = "$MT6000_2G_BEST" ]; then
    MT6000_2G_STATUS="✅"
else
    MT6000_2G_STATUS="💡→$MT6000_2G_BEST"
fi

if [ "$MT6000_5G_CH" = "$MT6000_5G_BEST" ]; then
    MT6000_5G_STATUS="✅"
else
    MT6000_5G_STATUS="💡→$MT6000_5G_BEST"
fi

# ========== BERYL ==========
BERYL_OK=0
if ping -c 1 -W 2 "$BERYL_IP" >/dev/null 2>&1; then
    BERYL_OK=1

    BERYL_2G_CH=$(sshpass -p "$BERYL_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$BERYL_IP \
        'iwinfo wlan0 info 2>/dev/null | grep "Channel:" | awk "{print \$4}"' 2>/dev/null)

    BERYL_5G_CH=$(sshpass -p "$BERYL_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$BERYL_IP \
        'iwinfo wlan1 info 2>/dev/null | grep "Channel:" | awk "{print \$4}"' 2>/dev/null)

    # Verificar que obtuvo los canales
    [ -z "$BERYL_2G_CH" ] && BERYL_2G_CH="?"
    [ -z "$BERYL_5G_CH" ] && BERYL_5G_CH="?"

    # Para Beryl solo verificamos canales no solapados
    case "$BERYL_2G_CH" in
        1|6|11) BERYL_2G_STATUS="✅" ;;
        *) BERYL_2G_STATUS="⚠️" ;;
    esac
    BERYL_5G_STATUS="✅"
else
    BERYL_2G_CH="--"
    BERYL_5G_CH="--"
    BERYL_2G_STATUS="❌"
    BERYL_5G_STATUS="❌"
fi

# ========== AUTO CAMBIO ==========
CHANGED=""
MT6000_CHANGED=""
if [ -n "$AUTO" ]; then
    # MT6000 2.4GHz
    if [ "$MT6000_2G_CH" != "$MT6000_2G_BEST" ]; then
        uci set wireless.radio0.channel="$MT6000_2G_BEST"
        uci commit wireless
        MT6000_CHANGED="1"
        CHANGED="${CHANGED}MT6000 2.4G: $MT6000_2G_CH→$MT6000_2G_BEST\n"
    fi

    # MT6000 5GHz
    if [ "$MT6000_5G_CH" != "$MT6000_5G_BEST" ]; then
        uci set wireless.radio1.channel="$MT6000_5G_BEST"
        uci commit wireless
        MT6000_CHANGED="1"
        CHANGED="${CHANGED}MT6000 5G: $MT6000_5G_CH→$MT6000_5G_BEST\n"
    fi

    # Aplicar cambios MT6000
    if [ -n "$MT6000_CHANGED" ]; then
        wifi reload
        sleep 3
    fi

    # Beryl 2.4GHz - asegurar canal no solapado y diferente al MT6000
    if [ "$BERYL_OK" = "1" ]; then
        BERYL_NEEDS_CHANGE=""
        BERYL_NEW_CH=""

        # Verificar si Beryl está en canal no óptimo
        case "$BERYL_2G_CH" in
            1|6|11) ;;  # Canal válido
            *) BERYL_NEEDS_CHANGE="1" ;;
        esac

        # Verificar si Beryl está en el mismo canal que MT6000
        if [ "$BERYL_2G_CH" = "$MT6000_2G_BEST" ]; then
            BERYL_NEEDS_CHANGE="1"
        fi

        if [ -n "$BERYL_NEEDS_CHANGE" ]; then
            # Elegir canal diferente al MT6000
            case "$MT6000_2G_BEST" in
                1) BERYL_NEW_CH="11" ;;
                6) BERYL_NEW_CH="11" ;;
                11) BERYL_NEW_CH="6" ;;
                *) BERYL_NEW_CH="11" ;;
            esac

            sshpass -p "$BERYL_PASS" ssh -o StrictHostKeyChecking=no root@$BERYL_IP \
                "uci set wireless.radio0.channel=$BERYL_NEW_CH && uci commit wireless && wifi reload" 2>/dev/null
            CHANGED="${CHANGED}Beryl 2.4G: $BERYL_2G_CH→$BERYL_NEW_CH\n"
            logger -t "wifi_monitor" "Beryl auto-cambio: $BERYL_2G_CH -> $BERYL_NEW_CH"
        fi
    fi
fi

# ========== VERBOSE ==========
if [ -n "$VERBOSE" ]; then
    echo "========================================"
    echo "       WiFi Channel Monitor"
    echo "========================================"
    echo ""
    echo "=== GL-MT6000 ==="
    echo "2.4 GHz: CH $MT6000_2G_CH ($MT6000_2G_COUNT redes) $MT6000_2G_STATUS"
    echo "5 GHz:   CH $MT6000_5G_CH ($MT6000_5G_COUNT redes) $MT6000_5G_STATUS"
    echo ""
    echo "=== Beryl ==="
    if [ "$BERYL_OK" = "1" ]; then
        echo "2.4 GHz: CH $BERYL_2G_CH $BERYL_2G_STATUS"
        echo "5 GHz:   CH $BERYL_5G_CH $BERYL_5G_STATUS"
    else
        echo "❌ No responde ($BERYL_IP)"
    fi

    if [ -n "$CHANGED" ]; then
        echo ""
        echo "=== CAMBIOS ==="
        echo -e "$CHANGED"
    fi
    echo "========================================"
fi

# ========== TELEGRAM ==========
if [ -n "$NOTIFY" ]; then
    if [ "$BERYL_OK" = "1" ]; then
        BERYL_LINE1="├ 2.4 GHz: CH <b>$BERYL_2G_CH</b> $BERYL_2G_STATUS"
        BERYL_LINE2="└ 5 GHz: CH <b>$BERYL_5G_CH</b> $BERYL_5G_STATUS"
    else
        BERYL_LINE1="└ ❌ No responde"
        BERYL_LINE2=""
    fi

    CAMBIOS_MSG=""
    if [ -n "$CHANGED" ]; then
        CAMBIOS_MSG="
<b>🔄 Cambios:</b> $(echo -e "$CHANGED" | tr '\n' ' ')"
    fi

    MENSAJE="<b>📡 WiFi Monitor</b>
<code>━━━━━━━━━━━━━━━━━━━━</code>
<b>GL-MT6000</b>
├ 2.4 GHz: CH <b>$MT6000_2G_CH</b> ($MT6000_2G_COUNT redes) $MT6000_2G_STATUS
└ 5 GHz: CH <b>$MT6000_5G_CH</b> ($MT6000_5G_COUNT redes) $MT6000_5G_STATUS

<b>Beryl</b>
$BERYL_LINE1
$BERYL_LINE2
$CAMBIOS_MSG
<code>━━━━━━━━━━━━━━━━━━━━</code>
$FECHA"

    curl -s -X POST --connect-timeout 10 \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${MENSAJE}" \
        -d "parse_mode=HTML" \
        -d "disable_notification=true"

    if [ $? -eq 0 ]; then
        echo "Reporte enviado a Telegram"
    else
        echo "ERROR: Fallo al enviar a Telegram"
        logger -t wifi_monitor "ERROR: curl fallo al enviar a Telegram"
    fi
fi

logger -t "wifi_monitor" "MT6000: 2.4G=$MT6000_2G_CH 5G=$MT6000_5G_CH | Beryl: 2.4G=$BERYL_2G_CH 5G=$BERYL_5G_CH"
