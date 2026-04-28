#!/bin/sh

IF1="pppoe-wan"
IF2="lan5"
THRESH1=250
THRESH2=110
INTERVAL=5

get_bytes() {
  grep "^ *$1:" /proc/net/dev | awk '{print $2 + $10}'
}

B1_START=$(get_bytes "$IF1")
B2_START=$(get_bytes "$IF2")

sleep "$INTERVAL"

B1_END=$(get_bytes "$IF1")
B2_END=$(get_bytes "$IF2")

echo "[$IF1] START=$B1_START, END=$B1_END"
echo "[$IF2] START=$B2_START, END=$B2_END"

for val in "$B1_START" "$B1_END" "$B2_START" "$B2_END"; do
  echo "$val" | grep -Eq '^[0-9]+$' || { echo "❌ Invalid numeric value: $val"; exit 1; }
done

B1_MBPS=$(( (B1_END - B1_START) * 8 / INTERVAL / 1000000 ))
B2_MBPS=$(( (B2_END - B2_START) * 8 / INTERVAL / 1000000 ))

echo "$IF1: $B1_MBPS Mbps"
echo "$IF2: $B2_MBPS Mbps"

[ "$B1_MBPS" -ge "$THRESH1" ] && echo "✅ $IF1 meets threshold" || echo "⚠️ $IF1 below threshold"
[ "$B2_MBPS" -ge "$THRESH2" ] && echo "✅ $IF2 meets threshold" || echo "⚠️ $IF2 below threshold"
