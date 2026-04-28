#!/bin/sh
# lan-monitor.sh
# Autor: Jose Luis Abraham Charur
# Monitoreo de LAN con nload + tc + alertas Telegram

IFACE="pppoe-wan"
LIMIT_RX=800   # Mbps límite de tráfico entrante
LIMIT_TX=800   # Mbps límite de tráfico saliente
DROP_LIMIT=10  # Número de drops que dispara alerta
REQUEUE_LIMIT=50000  # Número de requeues que dispara alerta

# Configuración de Telegram (ejemplo)
BOT_TOKEN="123456789:ABCDefGhIjKlMnOpQrStUvWxYz1234567890"
CHAT_ID="987654321"

send_alert() {
  MSG="$1"
  curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
       -d chat_id="$CHAT_ID" \
       -d text="$MSG" >/dev/null
}

# --- Monitoreo con nload (tráfico LAN) ---
RX=$(nload -u M -t 1000 $IFACE 2>/dev/null | grep "Curr:" | awk '{print $2}')
TX=$(nload -u M -t 1000 $IFACE 2>/dev/null | grep "Curr:" | awk '{print $5}')

if [ "$RX" -gt "$LIMIT_RX" ]; then
  send_alert "⚠️ Congestión LAN $IFACE: RX $RX Mbps supera $LIMIT_RX Mbps"
fi

if [ "$TX" -gt "$LIMIT_TX" ]; then
  send_alert "⚠️ Congestión LAN $IFACE: TX $TX Mbps supera $LIMIT_TX Mbps"
fi

# --- Monitoreo de colas con tc ---
STATS=$(tc -s qdisc show dev $IFACE)
DROPS=$(echo "$STATS" | grep -o "drops [0-9]*" | awk '{print $2}' | head -n1)
REQUEUES=$(echo "$STATS" | grep -o "requeues [0-9]*" | awk '{print $2}' | head -n1)

if [ "$DROPS" -gt "$DROP_LIMIT" ]; then
  send_alert "⚠️ LAN $IFACE: $DROPS drops detectados en colas"
fi

if [ "$REQUEUES" -gt "$REQUEUE_LIMIT" ]; then
  send_alert "⚠️ LAN $IFACE: $REQUEUES requeues detectados en colas"
fi
