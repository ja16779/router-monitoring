#!/bin/sh

# === CONFIGURATION ===
BOT_TOKEN="REDACTED_BOT_TOKEN"
CHAT_ID="716542586"

# === RUN TEST AND PARSE OUTPUT ===
OUTPUT=$(sh /etc/script/netperfrunnertelmex.sh)
DL=$(echo "$OUTPUT" | awk "/Download:/ {print \$2}")
UL=$(echo "$OUTPUT" | awk "/Upload:/ {print \$2}")

# === FORMAT MESSAGE ===
MSG="🌐 *TELMEX*

⬇️ Download: *${DL} Mbps*
⬆️ Upload: *${UL} Mbps*"

# === SEND TO TELEGRAM ===
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="${CHAT_ID}" \
  -d parse_mode="Markdown" \
  -d text="$MSG"
