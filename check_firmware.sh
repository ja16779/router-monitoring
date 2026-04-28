#!/bin/sh
# Check GL-iNet firmware versions for Flint-2 and Beryl AX

LOGTAG="firmware-check"
TELEGRAM_TOKEN="REDACTED_BOT_TOKEN"
TELEGRAM_CHAT_ID="716542586"
MT6000_LIST_URL="https://fw.gl-inet.com/firmware/mt6000-open/testing/list-sha256.txt"
MT3000_LIST_URL="https://fw.gl-inet.com/firmware/mt3000-open/testing/list-sha256.txt"

send_telegram() {
    local message="$1"
    curl -skim 10 \
        --data disable_notification="false" \
        --data parse_mode="HTML" \
        --data chat_id="$TELEGRAM_CHAT_ID" \
        --data-urlencode "text=$message" \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" >/dev/null 2>&1
}

get_local_info() {
    local model=$(cat /tmp/sysinfo/model 2>/dev/null)
    local fw=$(cat /etc/glversion 2>/dev/null)
    local owrt=$(grep DISTRIB_RELEASE /etc/openwrt_release 2>/dev/null | cut -d"'" -f2)
    echo "${model}|${fw}|${owrt}"
}

get_remote_info() {
    sshpass -p admin ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@192.168.10.2 \
        "cat /tmp/sysinfo/model; echo '|'; cat /etc/glversion; echo '|'; grep DISTRIB_RELEASE /etc/openwrt_release | cut -d\\' -f2" 2>/dev/null | tr -d '\n'
}

get_latest_fw() {
    local model="$1"
    local latest

    case "$model" in
        *MT6000*)
            local list
            list=$(curl -skim 15 "$MT6000_LIST_URL" 2>/dev/null)
            latest=$(echo "$list" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+-op[0-9]+' | sort -V | tail -1)
            ;;
        *MT3000*)
            local list
            list=$(curl -skim 15 "$MT3000_LIST_URL" 2>/dev/null)
            latest=$(echo "$list" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+-op[0-9]+' | sort -V | tail -1)
            ;;
        *)
            echo "unknown"; return ;;
    esac

    [ -z "$latest" ] && latest="N/A"
    echo "$latest"
}

LOCAL_INFO=$(get_local_info)
LOCAL_MODEL=$(echo "$LOCAL_INFO" | cut -d'|' -f1)
LOCAL_FW=$(echo "$LOCAL_INFO" | cut -d'|' -f2)
LOCAL_OWRT=$(echo "$LOCAL_INFO" | cut -d'|' -f3)

REMOTE_INFO=$(get_remote_info)
REMOTE_MODEL=$(echo "$REMOTE_INFO" | cut -d'|' -f1)
REMOTE_FW=$(echo "$REMOTE_INFO" | cut -d'|' -f2)
REMOTE_OWRT=$(echo "$REMOTE_INFO" | cut -d'|' -f3)

LATEST_LOCAL=$(get_latest_fw "$LOCAL_MODEL")
LATEST_REMOTE=$(get_latest_fw "$REMOTE_MODEL")

if [ "$LOCAL_FW" = "$LATEST_LOCAL" ]; then
    LOCAL_STATUS="Up to date"
else
    LOCAL_STATUS="Update available: $LATEST_LOCAL"
fi

if [ "$REMOTE_FW" = "$LATEST_REMOTE" ]; then
    REMOTE_STATUS="Up to date"
else
    REMOTE_STATUS="Update available: $LATEST_REMOTE"
fi

HEADER="<b>#FirmwareCheck</b>"
LOCAL_MSG="<b>${LOCAL_MODEL}</b>
<pre>
FW Version:    ${LOCAL_FW}
OpenWrt:       ${LOCAL_OWRT}
Latest:        ${LATEST_LOCAL}
Status:        ${LOCAL_STATUS}
</pre>"
REMOTE_MSG="<b>${REMOTE_MODEL}</b>
<pre>
FW Version:    ${REMOTE_FW}
OpenWrt:       ${REMOTE_OWRT}
Latest:        ${LATEST_REMOTE}
Status:        ${REMOTE_STATUS}
</pre>"

MSG="${HEADER}

${LOCAL_MSG}

${REMOTE_MSG}"

logger -t "$LOGTAG" "Flint-2: $LOCAL_FW (latest: $LATEST_LOCAL) | Beryl: $REMOTE_FW (latest: $LATEST_REMOTE)"
send_telegram "$MSG"
echo "$MSG" | sed 's/<[^>]*>//g'
