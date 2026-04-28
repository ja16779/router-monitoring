#!/bin/sh
# NextDNS Quota Monitor v2
# Opción 1: Monitoreo manual (user configures query count)
# Opción 2: Consulta dashboard via Web (requiere API key)
# Opción 3: Monitorea logs de AdGuardHome

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

# Opción 1: MANUAL — Configurar valores manualmente
QUOTA_LIMIT=300000

# Opción 2: API KEY (obtener de NextDNS dashboard → Settings → API)
NEXTDNS_PROFILE="47a69f"
NEXTDNS_API_KEY="35fcdecd8d64df3b7b0003011d05996fbf703330"  # Configurada

# Umbrales de alerta
WARNING_THRESHOLD=80      # Alerta al 80%
CRITICAL_THRESHOLD=95     # Alerta al 95%

# ═══════════════════════════════════════════════════════════════════════════
# GET CREDENTIALS
# ═══════════════════════════════════════════════════════════════════════════

get_telegram_creds() {
    if [ -f "/etc/monitor/config.sh" ]; then
        TELEGRAM_BOT_TOKEN=$(grep "^TELEGRAM_BOT_TOKEN=" /etc/monitor/config.sh | cut -d'"' -f2)
        TELEGRAM_CHAT_ID=$(grep "^TELEGRAM_CHAT_ID=" /etc/monitor/config.sh | cut -d'"' -f2)
    fi

    if [ -z "$TELEGRAM_BOT_TOKEN" ] && [ -f "/etc/threat-alert/config.sh" ]; then
        TELEGRAM_BOT_TOKEN=$(grep "^TELEGRAM_BOT_TOKEN=" /etc/threat-alert/config.sh | cut -d'"' -f2)
        TELEGRAM_CHAT_ID=$(grep "^TELEGRAM_CHAT_ID=" /etc/threat-alert/config.sh | cut -d'"' -f2)
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# METHOD 1: Query AdGuardHome Log
# ═══════════════════════════════════════════════════════════════════════════

get_queries_from_adguardhome() {
    # Get queries from today (approximate count from AGH)
    # Returns estimated monthly projection

    # Get today's query count from AGH statistics
    # This is a rough estimate - needs AGH API access

    TODAY_QUERIES=$(curl -s -m 3 "http://127.0.0.1:3000/control/stats" 2>/dev/null | \
        grep -o '"dns_queries":[0-9]*' | cut -d: -f2)

    if [ -z "$TODAY_QUERIES" ] || [ "$TODAY_QUERIES" = "0" ]; then
        echo "0"
        return 1
    fi

    # Rough estimate: today's queries * 30 days
    DAY_OF_MONTH=$(date +%d)
    ESTIMATED_MONTHLY=$((TODAY_QUERIES * 30 / DAY_OF_MONTH))

    echo "$ESTIMATED_MONTHLY"
}

# ═══════════════════════════════════════════════════════════════════════════
# METHOD 2: Consulta API NextDNS (requiere API key)
# ═══════════════════════════════════════════════════════════════════════════

get_queries_from_api() {
    if [ -z "$NEXTDNS_API_KEY" ]; then
        return 1
    fi

    # Get profile ID and API key from NextDNS
    # https://my.nextdns.io/account (API key location)

    # Query analytics API (correct endpoint: no /v1/)
    RESPONSE=$(curl -s -m 10 \
        "https://api.nextdns.io/profiles/${NEXTDNS_PROFILE}/analytics/status" \
        -H "X-Api-Key: ${NEXTDNS_API_KEY}" \
        -H "Accept: application/json" \
        2>/dev/null)

    if [ -z "$RESPONSE" ]; then
        return 1
    fi

    # Extract and sum all queries (default + blocked + relayed)
    QUERIES=$(echo "$RESPONSE" | grep -o '"queries":[0-9]*' | cut -d: -f2 | awk '{sum+=$1} END {print sum}')

    if [ -z "$QUERIES" ] || [ "$QUERIES" = "0" ]; then
        return 1
    fi

    echo "$QUERIES"
}

# ═══════════════════════════════════════════════════════════════════════════
# METHOD 3: Manual Count (User updates file)
# ═══════════════════════════════════════════════════════════════════════════

get_queries_manual() {
    if [ -f "/tmp/nextdns_queries.txt" ]; then
        cat /tmp/nextdns_queries.txt
    else
        echo "0"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# GET QUERIES (try all methods)
# ═══════════════════════════════════════════════════════════════════════════

get_nextdns_queries() {
    # Intenta en orden: API → AdGuardHome → Manual

    local queries=""

    # Try API first (most accurate)
    if [ -n "$NEXTDNS_API_KEY" ]; then
        queries=$(get_queries_from_api)
        if [ "$queries" != "0" ] && [ -n "$queries" ]; then
            echo "$queries"
            return 0
        fi
    fi

    # Try AdGuardHome (rough estimate)
    queries=$(get_queries_from_adguardhome)
    if [ "$queries" != "0" ] && [ -n "$queries" ]; then
        echo "$queries (estimate)"
        return 0
    fi

    # Try manual
    queries=$(get_queries_manual)
    echo "$queries"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════
# SEND TELEGRAM ALERT
# ═══════════════════════════════════════════════════════════════════════════

send_telegram_alert() {
    local percent=$1
    local queries=$2
    local remaining=$3

    get_telegram_creds

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        return
    fi

    local emoji="⚠️"
    local color="🟡"
    [ $percent -gt 95 ] && emoji="🚨" && color="🔴"

    local message="${emoji} *NextDNS QUOTA ALERT*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Uso: ${queries} / ${QUOTA_LIMIT} queries
Porcentaje: ${percent}% ${color}
Restante: ${remaining} queries

Límite/día: $((QUOTA_LIMIT / 30)) queries
Día del mes: $(date +%d)
Promedio/día: $((queries / $(date +%d)))

⏰ $(date '+%Y-%m-%d %H:%M UTC')"

    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "text=$message" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "parse_mode=Markdown" \
        > /dev/null 2>&1
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════

case "${1:---check}" in
    --check)
        QUERIES_OUTPUT=$(get_nextdns_queries)
        QUERIES=$(echo "$QUERIES_OUTPUT" | awk '{print $1}')

        if [ "$QUERIES" = "0" ]; then
            echo "❌ Error: No se pudo obtener estadísticas"
            echo ""
            echo "Opciones de configuración:"
            echo ""
            echo "1. MANUAL (más fácil):"
            echo "   - Entra a https://dashboard.nextdns.io/"
            echo "   - Ve a 'Analytics' → Busca 'Queries today' o similar"
            echo "   - Ejecuta: echo 'CANTIDAD' > /tmp/nextdns_queries.txt"
            echo "   - Luego: $0 --check"
            echo ""
            echo "2. API KEY (automático):"
            echo "   - Entra a https://dashboard.nextdns.io/settings/api"
            echo "   - Copia tu API key"
            echo "   - Edita este script y configura: NEXTDNS_API_KEY=\"tu_key_aqui\""
            echo ""
            echo "3. Monitor AdGuardHome (estima):"
            echo "   - Este script intenta leer de AdGuardHome automáticamente"
            exit 1
        fi

        REMAINING=$((QUOTA_LIMIT - QUERIES))
        PERCENT=$((QUERIES * 100 / QUOTA_LIMIT))

        echo "NextDNS Quota Status:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Queries este mes:       $QUERIES_OUTPUT / $QUOTA_LIMIT"
        echo "Uso:                    ${PERCENT}%"
        echo "Restante:               $REMAINING queries"
        echo ""

        # Calcular días desde fecha de inicio personalizada
        # Usar /tmp/nextdns_cycle_start.txt si existe (formato: YYYY-MM-DD)
        # Si no existe, usar el 1º del mes actual

        if [ -f "/tmp/nextdns_cycle_start.txt" ]; then
            CYCLE_START=$(cat /tmp/nextdns_cycle_start.txt | xargs)
        else
            # Default: 1º del mes actual
            CYCLE_START="$(date +%Y-%m)-01"
        fi

        # Calcular días transcurridos desde el inicio del ciclo
        TODAY=$(date +%Y-%m-%d)
        DAYS_ELAPSED=$(( ($(date -d "$TODAY" +%s) - $(date -d "$CYCLE_START" +%s)) / 86400 + 1 ))

        # Calcular promedio real desde el 1º del mes
        if [ "$DAYS_ELAPSED" -gt 0 ]; then
            QUERIES_PER_DAY=$((QUERIES / DAYS_ELAPSED))
        else
            QUERIES_PER_DAY=0
        fi

        # Calcular promedio de límite diario
        DAILY_LIMIT=$((QUOTA_LIMIT / 30))

        echo "Estadísticas (desde $CYCLE_START):"
        echo "  Día del ciclo:           $DAYS_ELAPSED / 30 días"
        echo "  Límite diario (promedio): $DAILY_LIMIT queries/día"
        echo "  Uso actual/día:          $QUERIES_PER_DAY queries/día"
        echo ""

        # Calcular cuándo se acabaría la cuota
        DAYS_REMAINING=$((30 - DAYS_ELAPSED))
        if [ "$QUERIES_PER_DAY" -gt 0 ]; then
            DAYS_UNTIL_QUOTA=$((REMAINING / QUERIES_PER_DAY))
        else
            DAYS_UNTIL_QUOTA=999
        fi

        # Si se acaba antes del mes, mostrar fecha exacta
        if [ "$DAYS_UNTIL_QUOTA" -lt "$DAYS_REMAINING" ]; then
            ESTIMATED_END_DATE=$(date -d "+${DAYS_UNTIL_QUOTA} days" "+%d de %B" 2>/dev/null || echo "fecha calculada")
            EXHAUSTED="Se acabaría: $ESTIMATED_END_DATE (en ~$DAYS_UNTIL_QUOTA días)"
        else
            NEXT_MONTH=$(date -d "+1 month" "+%d de %B" 2>/dev/null || echo "próximo mes")
            EXHAUSTED="OK hasta: $NEXT_MONTH (ciclo se reinicia)"
        fi

        PROJECTED_TOTAL=$((QUERIES_PER_DAY * 30))

        echo "Proyección a fin de mes (30 días):"
        echo "  Si continúas a este ritmo: $PROJECTED_TOTAL queries"
        echo "  $EXHAUSTED"
        echo ""

        # Calcular próximo reset (30 días desde el inicio del ciclo)
        NEXT_RESET_DATE=$(date -d "$CYCLE_START +30days" "+%Y-%m-%d" 2>/dev/null || date -d "$(date -d "$CYCLE_START" +%s)+2592000" 2>/dev/null)
        NEXT_RESET_DISPLAY=$(date -d "$CYCLE_START +30days" "+%d de %B, %Y" 2>/dev/null || echo "en 30 días")
        echo "Reset de ciclo: $NEXT_RESET_DISPLAY"
        echo ""
        echo "💡 Tip: Cambiar fecha de inicio con:"
        echo "   echo 'YYYY-MM-DD' > /tmp/nextdns_cycle_start.txt"
        echo ""

        if [ $PERCENT -gt 95 ]; then
            echo "🔴 CRÍTICO: Estás usando más del 95% de tu cuota"
        elif [ $PERCENT -gt 80 ]; then
            echo "🟡 ADVERTENCIA: Estás usando más del 80% de tu cuota"
        else
            echo "🟢 OK: Uso dentro de los límites"
        fi
        ;;

    --set-queries)
        # Manual set: $0 --set-queries 125000
        if [ -z "$2" ]; then
            echo "Usage: $0 --set-queries NUMBER"
            echo "Example: $0 --set-queries 125000"
            exit 1
        fi
        echo "$2" > /tmp/nextdns_queries.txt
        echo "✓ Guardado: $2 queries en /tmp/nextdns_queries.txt"
        $0 --check
        ;;

    --alert)
        # Check and send alert if needed
        QUERIES_OUTPUT=$(get_nextdns_queries)
        QUERIES=$(echo "$QUERIES_OUTPUT" | awk '{print $1}')

        if [ "$QUERIES" = "0" ]; then
            exit 1
        fi

        REMAINING=$((QUOTA_LIMIT - QUERIES))
        PERCENT=$((QUERIES * 100 / QUOTA_LIMIT))

        if [ $PERCENT -gt $CRITICAL_THRESHOLD ]; then
            send_telegram_alert $PERCENT $QUERIES $REMAINING
            echo "🚨 Alerta crítica enviada ($PERCENT%)"
        elif [ $PERCENT -gt $WARNING_THRESHOLD ]; then
            send_telegram_alert $PERCENT $QUERIES $REMAINING
            echo "⚠️ Alerta de advertencia enviada ($PERCENT%)"
        else
            echo "✓ Uso normal ($PERCENT%)"
        fi
        ;;

    --live)
        # Real-time monitoring
        while true; do
            clear
            echo "╔════════════════════════════════════════════════════════════════╗"
            echo "║  NextDNS QUOTA MONITOR (Real-time)                            ║"
            echo "╚════════════════════════════════════════════════════════════════╝"
            echo ""

            QUERIES_OUTPUT=$(get_nextdns_queries)
            QUERIES=$(echo "$QUERIES_OUTPUT" | awk '{print $1}')

            if [ "$QUERIES" = "0" ]; then
                echo "⚠️ No hay datos disponibles"
                echo "   Configura el script con --set-queries o API key"
            else
                REMAINING=$((QUOTA_LIMIT - QUERIES))
                PERCENT=$((QUERIES * 100 / QUOTA_LIMIT))

                # Progress bar
                FILLED=$((PERCENT / 5))
                EMPTY=$((20 - FILLED))

                echo "Queries este mes:"
                echo "  $QUERIES_OUTPUT / $QUOTA_LIMIT"
                echo ""
                printf "Uso: ["
                for i in $(seq 1 $FILLED); do printf "█"; done
                for i in $(seq 1 $EMPTY); do printf "░"; done
                printf "] ${PERCENT}%%\n"
                echo ""

                echo "Restante:          $REMAINING queries"
                echo "Promedio/día:      $((QUERIES / $(date +%d))) queries/día"
                echo "Límite/día:        $((QUOTA_LIMIT / 30)) queries/día"
                echo ""

                if [ $PERCENT -gt 95 ]; then
                    echo "🔴 CRÍTICO: >95% usado"
                elif [ $PERCENT -gt 80 ]; then
                    echo "🟡 WARNING: >80% usado"
                else
                    echo "🟢 OK: Uso normal"
                fi
            fi

            echo ""
            echo "Actualizado: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Ctrl+C para salir"
            sleep 10
        done
        ;;

    *)
        echo "NextDNS Quota Monitor"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --check              Check current quota usage"
        echo "  --set-queries NUM    Set queries manually (e.g., 125000)"
        echo "  --alert              Check and send Telegram alert if >80%"
        echo "  --live               Real-time dashboard"
        echo ""
        echo "Setup:"
        echo ""
        echo "Option 1 (MANUAL - Easiest):"
        echo "  1. Go to https://dashboard.nextdns.io/"
        echo "  2. Check 'Queries today' in Analytics"
        echo "  3. Run: $0 --set-queries <number>"
        echo "  4. Setup cron: 0 * * * * $0 --alert"
        echo ""
        echo "Option 2 (API - Automatic):"
        echo "  1. Go to https://dashboard.nextdns.io/settings/api"
        echo "  2. Copy API key"
        echo "  3. Edit script and set: NEXTDNS_API_KEY=\"your_key_here\""
        echo "  4. Setup cron: 0 * * * * $0 --alert"
        echo ""
        echo "Examples:"
        echo "  $0 --set-queries 145000    # Set 145k queries"
        echo "  $0 --check                 # Check now"
        echo "  $0 --live                  # Real-time view"
        ;;
esac
