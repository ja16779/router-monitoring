#!/bin/sh
# luci-app-linkmonitor v2.0 installer for OpenWrt
# Features: Speed Test per WAN, Telegram alerts, Multi-WAN interface monitoring
# Usage: pscp install.sh root@192.168.8.1:/tmp/ && plink root@192.168.8.1 'sh /tmp/install.sh'

echo "========================================="
echo " Installing luci-app-linkmonitor v2.0.0"
echo " Speed Test + Telegram + Multi-WAN"
echo "========================================="

# Stop existing daemon
/etc/init.d/linkmonitor stop 2>/dev/null

# Create directories
mkdir -p /etc/config
mkdir -p /etc/init.d
mkdir -p /usr/bin
mkdir -p /usr/libexec/rpcd
mkdir -p /usr/share/luci/menu.d
mkdir -p /usr/share/rpcd/acl.d
mkdir -p /www/luci-static/resources/view/linkmonitor
mkdir -p /tmp/linkmonitor

# ============================================================
# [1/8] UCI Configuration
# ============================================================
echo "[1/8] Writing UCI config..."
cat > /etc/config/linkmonitor << 'UCIEOF'
config global 'global'
	option enabled '1'
	option interval '30'
	option history_size '200'
	option speed_enabled '1'
	option speed_interval '1800'
	option download_url 'http://proof.ovh.net/files/10Mb.dat'
	option upload_url 'http://devnull-as-a-service.com/dev/null'
	option upload_size '5'
	option speed_history_size '500'

config interface
	option enabled '1'
	option name 'WAN'
	option ifname 'eth1'
	option uci_iface 'wan'
	option host '8.8.8.8'
	option method 'ping'
	option interval '30'
	option timeout '5'
	option retries '3'
	option speed_test '1'

config interface
	option enabled '1'
	option name 'SecondWAN'
	option ifname 'lan5'
	option uci_iface 'secondwan'
	option host '1.1.1.1'
	option method 'ping'
	option interval '30'
	option timeout '5'
	option retries '3'
	option speed_test '1'

config interface
	option enabled '0'
	option name 'Wireless WAN'
	option ifname ''
	option uci_iface 'wwan'
	option host '8.8.4.4'
	option method 'ping'
	option interval '60'
	option timeout '5'
	option retries '3'
	option speed_test '0'

config interface
	option enabled '0'
	option name 'Tethering'
	option ifname ''
	option uci_iface 'tethering'
	option host '8.8.8.8'
	option method 'ping'
	option interval '60'
	option timeout '5'
	option retries '3'
	option speed_test '0'

config alert
	option enabled '1'
	option name 'System Log'
	option type 'syslog'
	option trigger 'both'

config alert
	option enabled '0'
	option name 'Telegram Bot'
	option type 'telegram'
	option trigger 'both'
	option bot_token ''
	option chat_id ''
	option notify_speed '1'
	option speed_threshold '10'

config alert
	option enabled '0'
	option name 'Webhook'
	option type 'webhook'
	option trigger 'both'
	option url 'https://hooks.example.com/linkmonitor'

config alert
	option enabled '0'
	option name 'Custom Script'
	option type 'script'
	option trigger 'down'
	option path '/usr/bin/linkmonitor-alert.sh'

config alert
	option enabled '0'
	option name 'Email Admin'
	option type 'email'
	option trigger 'both'
	option recipient 'admin@example.com'
	option subject_prefix '[LinkMonitor]'
UCIEOF

# ============================================================
# [2/8] Monitoring Daemon
# ============================================================
echo "[2/8] Writing monitoring daemon..."
cat > /usr/bin/linkmonitor-daemon << 'DAEMONEOF'
#!/bin/sh
# linkmonitor-daemon v2.0 - Multi-WAN speed test + Telegram + link monitoring
CONF="linkmonitor"
STATE_DIR="/tmp/linkmonitor"
HISTORY_FILE="$STATE_DIR/history.json"
STATUS_FILE="$STATE_DIR/status.json"
SPEED_HISTORY_FILE="$STATE_DIR/speed_history.json"
PID_FILE="/var/run/linkmonitor.pid"
MAX_HISTORY=200

mkdir -p "$STATE_DIR"
[ -f "$HISTORY_FILE" ] || echo '[]' > "$HISTORY_FILE"
[ -f "$STATUS_FILE" ] || echo '{}' > "$STATUS_FILE"
[ -f "$SPEED_HISTORY_FILE" ] || echo '[]' > "$SPEED_HISTORY_FILE"

log_msg() { logger -t linkmonitor "$1"; }
timestamp() { date +%s; }
timestamp_iso() { date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S"; }

read_global_config() {
    GLOBAL_ENABLED=$(uci -q get $CONF.global.enabled || echo "1")
    GLOBAL_INTERVAL=$(uci -q get $CONF.global.interval || echo "30")
    HISTORY_SIZE=$(uci -q get $CONF.global.history_size || echo "$MAX_HISTORY")
    SPEED_ENABLED=$(uci -q get $CONF.global.speed_enabled || echo "0")
    SPEED_INTERVAL=$(uci -q get $CONF.global.speed_interval || echo "1800")
    DOWNLOAD_URL=$(uci -q get $CONF.global.download_url || echo "")
    UPLOAD_URL=$(uci -q get $CONF.global.upload_url || echo "")
    UPLOAD_SIZE=$(uci -q get $CONF.global.upload_size || echo "5")
    SPEED_HISTORY_SIZE=$(uci -q get $CONF.global.speed_history_size || echo "500")
}

# ---- Resolve ifname from UCI interface if not set ----
resolve_ifname() {
    local iface_name="$1" configured_ifname="$2"
    if [ -n "$configured_ifname" ]; then
        echo "$configured_ifname"
        return
    fi
    # Try to get device from network config
    local dev=$(uci -q get "network.${iface_name}.device")
    [ -n "$dev" ] && echo "$dev" && return
    # Fallback: try ifstatus
    local phys=$(ifstatus "$iface_name" 2>/dev/null | jsonfilter -e '@["l3_device"]' 2>/dev/null)
    [ -n "$phys" ] && echo "$phys" && return
    echo ""
}

# ---- Check functions (interface-bound) ----
do_ping_check() {
    local host="$1" timeout="$2" count="${3:-3}" ifname="$4"
    local iface_opt=""
    [ -n "$ifname" ] && iface_opt="-I $ifname"
    result=$(ping $iface_opt -c "$count" -W "$timeout" "$host" 2>/dev/null)
    if [ $? -eq 0 ]; then
        latency=$(echo "$result" | grep -oE 'avg[^0-9]*([0-9.]+)' | grep -oE '[0-9.]+' | head -1)
        [ -z "$latency" ] && latency=$(echo "$result" | grep 'round-trip' | cut -d'/' -f5)
        [ -z "$latency" ] && latency="0"
        echo "$latency"
    else
        echo "fail"
    fi
}

do_http_check() {
    local url="$1" timeout="$2" ifname="$3"
    local iface_opt=""
    [ -n "$ifname" ] && iface_opt="--interface $ifname"
    local out=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" $iface_opt --connect-timeout "$timeout" --max-time "$timeout" "$url" 2>/dev/null)
    local code=$(echo "$out" | awk '{print $1}')
    local ttime=$(echo "$out" | awk '{print $2}')
    if [ "$code" -ge 200 ] && [ "$code" -lt 400 ] 2>/dev/null; then
        local ms=$(awk "BEGIN{printf \"%.0f\", $ttime * 1000}" 2>/dev/null || echo "1")
        [ "$ms" = "0" ] && ms=1
        echo "$ms"
    else
        echo "fail"
    fi
}

do_dns_check() {
    local host="$1" timeout="$2"
    local s=$(date +%s)
    nslookup "$host" >/dev/null 2>&1
    local rc=$? e=$(date +%s)
    if [ $rc -eq 0 ]; then
        local ms=$(( (e - s) * 1000 ))
        [ "$ms" -eq 0 ] && ms=1
        echo "$ms"
    else
        echo "fail"
    fi
}

# ---- Speed test function ----
do_speed_test() {
    local ifname="$1" iface_name="$2"
    local iface_opt=""
    [ -n "$ifname" ] && iface_opt="--interface $ifname"

    local dl_speed=0 ul_speed=0 dl_mbps="0.00" ul_mbps="0.00" latency=0

    # Latency first
    if [ -n "$ifname" ]; then
        local ping_result=$(ping -I "$ifname" -c 3 -W 5 8.8.8.8 2>/dev/null)
    else
        local ping_result=$(ping -c 3 -W 5 8.8.8.8 2>/dev/null)
    fi
    if [ $? -eq 0 ]; then
        latency=$(echo "$ping_result" | grep -oE 'avg[^0-9]*([0-9.]+)' | grep -oE '[0-9.]+' | head -1)
        [ -z "$latency" ] && latency="0"
    fi

    # Download test
    if [ -n "$DOWNLOAD_URL" ]; then
        dl_speed=$(curl -s -L $iface_opt -o /dev/null -w '%{speed_download}' -m 30 "$DOWNLOAD_URL" 2>/dev/null)
        if [ -n "$dl_speed" ] && [ "$dl_speed" != "0" ] && [ "$dl_speed" != "0.000" ]; then
            dl_mbps=$(awk "BEGIN{printf \"%.2f\", $dl_speed * 8 / 1000000}" 2>/dev/null || echo "0.00")
        fi
    fi

    # Upload test
    if [ -n "$UPLOAD_URL" ]; then
        ul_speed=$(dd if=/dev/zero bs=1M count=$UPLOAD_SIZE 2>/dev/null | curl -s -L $iface_opt -X POST -d @- -o /dev/null -w '%{speed_upload}' -m 30 "$UPLOAD_URL" 2>/dev/null)
        if [ -n "$ul_speed" ] && [ "$ul_speed" != "0" ] && [ "$ul_speed" != "0.000" ]; then
            ul_mbps=$(awk "BEGIN{printf \"%.2f\", $ul_speed * 8 / 1000000}" 2>/dev/null || echo "0.00")
        fi
    fi

    echo "${dl_mbps}|${ul_mbps}|${latency}"
}

# ---- Telegram function ----
send_telegram() {
    local token="$1" chat_id="$2" msg="$3"
    curl -s -m 10 "https://api.telegram.org/bot${token}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${msg}" \
        -d "parse_mode=HTML" >/dev/null 2>&1
}

# ---- Alert function (enhanced with telegram + speed) ----
trigger_alerts() {
    local link_name="$1" host="$2" new_state="$3" old_state="$4" latency="$5" ifname="$6" alert_type="$7"
    # alert_type: "state" or "speed"
    local dl_mbps="${8:-}" ul_mbps="${9:-}" threshold="${10:-}"

    local idx=0
    while true; do
        local atype=$(uci -q get "$CONF.@alert[$idx].type")
        [ -z "$atype" ] && break
        local aenabled=$(uci -q get "$CONF.@alert[$idx].enabled" || echo "0")
        [ "$aenabled" != "1" ] && { idx=$((idx+1)); continue; }

        local atrigger=$(uci -q get "$CONF.@alert[$idx].trigger" || echo "both")

        # For state alerts, check trigger direction
        if [ "$alert_type" = "state" ]; then
            case "$atrigger" in
                down) [ "$new_state" != "down" ] && { idx=$((idx+1)); continue; } ;;
                up)   [ "$new_state" != "up" ]   && { idx=$((idx+1)); continue; } ;;
            esac
        fi

        # For speed alerts, check notify_speed flag
        if [ "$alert_type" = "speed" ]; then
            local notify_speed=$(uci -q get "$CONF.@alert[$idx].notify_speed" || echo "0")
            [ "$notify_speed" != "1" ] && { idx=$((idx+1)); continue; }
        fi

        case "$atype" in
            syslog)
                if [ "$alert_type" = "speed" ]; then
                    log_msg "SPEED ALERT: '$link_name' ($ifname) DL:${dl_mbps}Mbps UL:${ul_mbps}Mbps below threshold ${threshold}Mbps"
                elif [ "$new_state" = "down" ]; then
                    log_msg "ALERT: Interface '$link_name' ($host via $ifname) is DOWN"
                else
                    log_msg "ALERT: Interface '$link_name' ($host via $ifname) recovered (UP, ${latency}ms)"
                fi ;;
            telegram)
                local token=$(uci -q get "$CONF.@alert[$idx].bot_token")
                local chat_id=$(uci -q get "$CONF.@alert[$idx].chat_id")
                if [ -n "$token" ] && [ -n "$chat_id" ]; then
                    local msg=""
                    if [ "$alert_type" = "speed" ]; then
                        msg="⚠️ <b>Speed Degradation</b>
🔌 Interface: <b>${link_name}</b> (${ifname})
⬇️ Download: <b>${dl_mbps} Mbps</b>
⬆️ Upload: <b>${ul_mbps} Mbps</b>
📊 Threshold: ${threshold} Mbps
🕐 $(timestamp_iso)"
                    elif [ "$new_state" = "down" ]; then
                        msg="🔴 <b>Link DOWN</b>
🔌 Interface: <b>${link_name}</b> (${ifname})
🌐 Host: ${host}
🕐 $(timestamp_iso)"
                    else
                        msg="🟢 <b>Link UP</b>
🔌 Interface: <b>${link_name}</b> (${ifname})
🌐 Host: ${host}
📶 Latency: ${latency}ms
🕐 $(timestamp_iso)"
                    fi
                    send_telegram "$token" "$chat_id" "$msg" &
                fi ;;
            email)
                local rcpt=$(uci -q get "$CONF.@alert[$idx].recipient")
                local pfx=$(uci -q get "$CONF.@alert[$idx].subject_prefix" || echo "[LinkMonitor]")
                if [ -n "$rcpt" ] && command -v sendmail >/dev/null 2>&1; then
                    if [ "$alert_type" = "speed" ]; then
                        echo -e "Subject: $pfx Speed Alert: $link_name\n\nInterface '$link_name' ($ifname)\nDL: ${dl_mbps}Mbps UL: ${ul_mbps}Mbps\nThreshold: ${threshold}Mbps\nTime: $(timestamp_iso)" | sendmail "$rcpt"
                    else
                        echo -e "Subject: $pfx $new_state: $link_name\n\nInterface '$link_name' ($host via $ifname) is $new_state.\nLatency: ${latency}ms\nTime: $(timestamp_iso)" | sendmail "$rcpt"
                    fi
                fi ;;
            script)
                local sp=$(uci -q get "$CONF.@alert[$idx].path")
                [ -n "$sp" ] && [ -x "$sp" ] && "$sp" "$link_name" "$host" "$new_state" "$latency" "$ifname" "$alert_type" "$dl_mbps" "$ul_mbps" & ;;
            webhook)
                local wu=$(uci -q get "$CONF.@alert[$idx].url")
                if [ -n "$wu" ]; then
                    if [ "$alert_type" = "speed" ]; then
                        curl -s -X POST -H "Content-Type: application/json" \
                            -d "{\"interface\":\"$link_name\",\"ifname\":\"$ifname\",\"type\":\"speed\",\"download\":$dl_mbps,\"upload\":$ul_mbps,\"threshold\":$threshold,\"time\":\"$(timestamp_iso)\"}" \
                            "$wu" >/dev/null 2>&1 &
                    else
                        curl -s -X POST -H "Content-Type: application/json" \
                            -d "{\"interface\":\"$link_name\",\"host\":\"$host\",\"ifname\":\"$ifname\",\"state\":\"$new_state\",\"latency\":$latency,\"time\":\"$(timestamp_iso)\"}" \
                            "$wu" >/dev/null 2>&1 &
                    fi
                fi ;;
        esac
        idx=$((idx+1))
    done
}

# ---- History functions ----
add_history_event() {
    local link_name="$1" host="$2" state="$3" latency="$4" ifname="$5"
    local ts=$(timestamp) ti=$(timestamp_iso)
    local ev="{\"name\":\"$link_name\",\"host\":\"$host\",\"state\":\"$state\",\"latency\":$latency,\"ifname\":\"$ifname\",\"timestamp\":$ts,\"time\":\"$ti\"}"
    if [ -f "$HISTORY_FILE" ] && [ "$(cat "$HISTORY_FILE" 2>/dev/null)" != "[]" ]; then
        sed -i "s/\]$/,$ev]/" "$HISTORY_FILE" 2>/dev/null || echo "[$ev]" > "$HISTORY_FILE"
    else
        echo "[$ev]" > "$HISTORY_FILE"
    fi
    # Trim history
    local count=$(grep -o '"timestamp"' "$HISTORY_FILE" 2>/dev/null | wc -l)
    if [ "$count" -gt "$HISTORY_SIZE" ]; then
        # Keep last HISTORY_SIZE entries by rewriting
        local tmp=$(cat "$HISTORY_FILE")
        echo "$tmp" | jsonfilter -e '@[-'"$HISTORY_SIZE"':]' > "$HISTORY_FILE" 2>/dev/null || true
    fi
}

add_speed_history() {
    local iface_name="$1" ifname="$2" dl_mbps="$3" ul_mbps="$4" latency="$5"
    local ts=$(timestamp) ti=$(timestamp_iso)
    local ev="{\"iface\":\"$iface_name\",\"ifname\":\"$ifname\",\"download\":$dl_mbps,\"upload\":$ul_mbps,\"latency\":$latency,\"timestamp\":$ts,\"time\":\"$ti\"}"
    if [ -f "$SPEED_HISTORY_FILE" ] && [ "$(cat "$SPEED_HISTORY_FILE" 2>/dev/null)" != "[]" ]; then
        sed -i "s/\]$/,$ev]/" "$SPEED_HISTORY_FILE" 2>/dev/null || echo "[$ev]" > "$SPEED_HISTORY_FILE"
    else
        echo "[$ev]" > "$SPEED_HISTORY_FILE"
    fi
}

# ---- Status update ----
update_status() {
    local lid="$1" lname="$2" lhost="$3" lmethod="$4" lstate="$5" llat="$6" lchange="$7" lfails="$8" lifname="$9"
    shift 9
    local luci_iface="$1" ldl="${2:-0}" lul="${3:-0}" lspeed_ts="${4:-0}"
    local ts=$(timestamp)
    echo "{\"name\":\"$lname\",\"host\":\"$lhost\",\"method\":\"$lmethod\",\"state\":\"$lstate\",\"latency\":$llat,\"last_check\":$ts,\"last_change\":$lchange,\"consecutive_fails\":$lfails,\"ifname\":\"$lifname\",\"uci_iface\":\"$luci_iface\",\"download\":$ldl,\"upload\":$lul,\"speed_timestamp\":$lspeed_ts}" > "$STATE_DIR/iface_${lid}.json"
    # Combine all interface status
    local combined="{" first=1
    for f in "$STATE_DIR"/iface_*.json; do
        [ -f "$f" ] || continue
        local id=$(basename "$f" .json | sed 's/iface_//')
        [ "$first" = "1" ] && combined="${combined}\"${id}\":$(cat "$f")" && first=0 || combined="${combined},\"${id}\":$(cat "$f")"
    done
    echo "${combined}}" > "$STATUS_FILE"
}

# ---- Main loop ----
monitor_loop() {
    log_msg "Link monitor daemon v2.0 started (PID $$)"
    echo $$ > "$PID_FILE"

    while true; do
        read_global_config
        [ "$GLOBAL_ENABLED" != "1" ] && { sleep "$GLOBAL_INTERVAL"; continue; }

        local idx=0
        while true; do
            local lname=$(uci -q get "$CONF.@interface[$idx].name")
            [ -z "$lname" ] && break
            local lenabled=$(uci -q get "$CONF.@interface[$idx].enabled" || echo "1")
            [ "$lenabled" != "1" ] && { idx=$((idx+1)); continue; }

            local lhost=$(uci -q get "$CONF.@interface[$idx].host")
            local lmethod=$(uci -q get "$CONF.@interface[$idx].method" || echo "ping")
            local ltimeout=$(uci -q get "$CONF.@interface[$idx].timeout" || echo "5")
            local lretries=$(uci -q get "$CONF.@interface[$idx].retries" || echo "3")
            local linterval=$(uci -q get "$CONF.@interface[$idx].interval" || echo "$GLOBAL_INTERVAL")
            local lifname_cfg=$(uci -q get "$CONF.@interface[$idx].ifname" || echo "")
            local luci_iface=$(uci -q get "$CONF.@interface[$idx].uci_iface" || echo "")
            local lspeed_test=$(uci -q get "$CONF.@interface[$idx].speed_test" || echo "0")

            # Resolve actual interface name
            local lifname=$(resolve_ifname "$luci_iface" "$lifname_cfg")

            local now=$(timestamp)

            # ---- Link check ----
            local lcf="$STATE_DIR/lastcheck_${idx}"
            local do_check=0
            if [ -f "$lcf" ]; then
                local lt=$(cat "$lcf") el=$((now - lt))
                [ "$el" -ge "$linterval" ] && do_check=1
            else
                do_check=1
            fi

            if [ "$do_check" = "1" ]; then
                echo "$now" > "$lcf"
                local result=""
                case "$lmethod" in
                    ping) result=$(do_ping_check "$lhost" "$ltimeout" "$lretries" "$lifname") ;;
                    http|https) result=$(do_http_check "$lhost" "$ltimeout" "$lifname") ;;
                    dns) result=$(do_dns_check "$lhost" "$ltimeout") ;;
                    *) result=$(do_ping_check "$lhost" "$ltimeout" "$lretries" "$lifname") ;;
                esac

                local new_state="up" latency=0
                if [ "$result" = "fail" ]; then new_state="down"; else latency="$result"; fi

                local psf="$STATE_DIR/prevstate_${idx}" prev_state="unknown"
                [ -f "$psf" ] && prev_state=$(cat "$psf")

                local ff="$STATE_DIR/fails_${idx}" consecutive_fails=0
                [ -f "$ff" ] && consecutive_fails=$(cat "$ff")
                [ "$new_state" = "down" ] && consecutive_fails=$((consecutive_fails+1)) || consecutive_fails=0
                echo "$consecutive_fails" > "$ff"

                local cf="$STATE_DIR/lastchange_${idx}" last_change=$now
                [ -f "$cf" ] && last_change=$(cat "$cf")

                if [ "$prev_state" != "$new_state" ] && [ "$prev_state" != "unknown" ]; then
                    echo "$now" > "$cf"; last_change=$now
                    trigger_alerts "$lname" "$lhost" "$new_state" "$prev_state" "$latency" "$lifname" "state"
                    add_history_event "$lname" "$lhost" "$new_state" "$latency" "$lifname"
                    log_msg "Interface '$lname' ($lhost via $lifname): $prev_state -> $new_state (${latency}ms)"
                elif [ "$prev_state" = "unknown" ]; then
                    echo "$now" > "$cf"; last_change=$now
                    add_history_event "$lname" "$lhost" "$new_state" "$latency" "$lifname"
                fi
                echo "$new_state" > "$psf"

                # Read last speed data for status
                local sdlf="$STATE_DIR/speed_dl_${idx}" sulf="$STATE_DIR/speed_ul_${idx}" sstf="$STATE_DIR/speed_ts_${idx}"
                local last_dl=0 last_ul=0 last_speed_ts=0
                [ -f "$sdlf" ] && last_dl=$(cat "$sdlf")
                [ -f "$sulf" ] && last_ul=$(cat "$sulf")
                [ -f "$sstf" ] && last_speed_ts=$(cat "$sstf")

                update_status "$idx" "$lname" "$lhost" "$lmethod" "$new_state" "$latency" "$last_change" "$consecutive_fails" "$lifname" "$luci_iface" "$last_dl" "$last_ul" "$last_speed_ts"
            fi

            # ---- Speed test ----
            if [ "$SPEED_ENABLED" = "1" ] && [ "$lspeed_test" = "1" ] && [ -n "$lifname" ]; then
                local stf="$STATE_DIR/lastspeed_${idx}"
                local do_speed=0
                if [ -f "$stf" ]; then
                    local lst=$(cat "$stf") sel=$((now - lst))
                    [ "$sel" -ge "$SPEED_INTERVAL" ] && do_speed=1
                else
                    do_speed=1
                fi

                if [ "$do_speed" = "1" ]; then
                    echo "$now" > "$stf"
                    log_msg "Running speed test for '$lname' via $lifname..."
                    local speed_result=$(do_speed_test "$lifname" "$lname")
                    local sdl=$(echo "$speed_result" | cut -d'|' -f1)
                    local sul=$(echo "$speed_result" | cut -d'|' -f2)
                    local slat=$(echo "$speed_result" | cut -d'|' -f3)
                    log_msg "Speed test '$lname' ($lifname): DL=${sdl}Mbps UL=${sul}Mbps Lat=${slat}ms"

                    # Store last speed
                    echo "$sdl" > "$STATE_DIR/speed_dl_${idx}"
                    echo "$sul" > "$STATE_DIR/speed_ul_${idx}"
                    echo "$now" > "$STATE_DIR/speed_ts_${idx}"

                    add_speed_history "$lname" "$lifname" "$sdl" "$sul" "$slat"

                    # Check speed threshold for alerts
                    local aidx=0
                    while true; do
                        local atype=$(uci -q get "$CONF.@alert[$aidx].type")
                        [ -z "$atype" ] && break
                        local aenabled=$(uci -q get "$CONF.@alert[$aidx].enabled" || echo "0")
                        local notify_speed=$(uci -q get "$CONF.@alert[$aidx].notify_speed" || echo "0")
                        if [ "$aenabled" = "1" ] && [ "$notify_speed" = "1" ]; then
                            local sthresh=$(uci -q get "$CONF.@alert[$aidx].speed_threshold" || echo "10")
                            local below=0
                            # Check if download is below threshold
                            below=$(awk "BEGIN{if($sdl < $sthresh) print 1; else print 0}" 2>/dev/null || echo "0")
                            if [ "$below" = "1" ]; then
                                trigger_alerts "$lname" "$lhost" "degraded" "up" "$slat" "$lifname" "speed" "$sdl" "$sul" "$sthresh"
                                break
                            fi
                        fi
                        aidx=$((aidx+1))
                    done

                    # Update status with new speed data
                    local psf="$STATE_DIR/prevstate_${idx}"
                    local ff="$STATE_DIR/fails_${idx}"
                    local cf="$STATE_DIR/lastchange_${idx}"
                    local cur_state="unknown" cur_fails=0 cur_change=$now cur_lat=0
                    [ -f "$psf" ] && cur_state=$(cat "$psf")
                    [ -f "$ff" ] && cur_fails=$(cat "$ff")
                    [ -f "$cf" ] && cur_change=$(cat "$cf")
                    update_status "$idx" "$lname" "$lhost" "$lmethod" "$cur_state" "$slat" "$cur_change" "$cur_fails" "$lifname" "$luci_iface" "$sdl" "$sul" "$now"
                fi
            fi

            idx=$((idx+1))
        done

        sleep "$GLOBAL_INTERVAL"
    done
}

trap 'log_msg "Link monitor daemon stopped"; rm -f "$PID_FILE"; exit 0' INT TERM
monitor_loop
DAEMONEOF
chmod +x /usr/bin/linkmonitor-daemon

# ============================================================
# [3/8] RPCd Backend
# ============================================================
echo "[3/8] Writing RPCd backend..."
cat > /usr/libexec/rpcd/linkmonitor << 'RPCDEOF'
#!/bin/sh
STATE_DIR="/tmp/linkmonitor"
STATUS_FILE="$STATE_DIR/status.json"
HISTORY_FILE="$STATE_DIR/history.json"
SPEED_HISTORY_FILE="$STATE_DIR/speed_history.json"
PID_FILE="/var/run/linkmonitor.pid"
CONF="linkmonitor"

handle_list() {
    echo '{"get_status":{},"get_history":{"limit":50},"clear_history":{},"get_config_summary":{},"test_link":{"host":"str","method":"str","timeout":5,"ifname":"str"},"get_daemon_status":{},"restart_daemon":{},"get_speed_history":{"limit":100},"clear_speed_history":{},"run_speed_test":{"ifname":"str","iface_name":"str"}}'
}

handle_get_status() {
    [ -f "$STATUS_FILE" ] && echo "{\"status\":$(cat "$STATUS_FILE")}" || echo '{"status":{}}'
}

handle_get_history() {
    read input
    if [ -f "$HISTORY_FILE" ]; then
        echo "{\"history\":$(cat "$HISTORY_FILE"),\"total\":0}"
    else
        echo '{"history":[],"total":0}'
    fi
}

handle_clear_history() {
    echo '[]' > "$HISTORY_FILE"
    echo '{"result":"ok"}'
}

handle_get_config_summary() {
    local ic=0 ac=0
    while uci -q get "$CONF.@interface[$ic].name" >/dev/null 2>&1; do ic=$((ic+1)); done
    while uci -q get "$CONF.@alert[$ac].type" >/dev/null 2>&1; do ac=$((ac+1)); done
    local en=$(uci -q get "$CONF.global.enabled" || echo "1")
    local iv=$(uci -q get "$CONF.global.interval" || echo "30")
    local se=$(uci -q get "$CONF.global.speed_enabled" || echo "0")
    echo "{\"enabled\":$en,\"interval\":$iv,\"interface_count\":$ic,\"alert_count\":$ac,\"speed_enabled\":$se}"
}

handle_test_link() {
    read input
    local host=$(echo "$input" | jsonfilter -e '@.host' 2>/dev/null)
    local method=$(echo "$input" | jsonfilter -e '@.method' 2>/dev/null || echo "ping")
    local timeout=$(echo "$input" | jsonfilter -e '@.timeout' 2>/dev/null || echo "5")
    local ifname=$(echo "$input" | jsonfilter -e '@.ifname' 2>/dev/null || echo "")
    [ -z "$host" ] && { echo '{"error":"host required"}'; return; }
    local iface_opt=""
    [ -n "$ifname" ] && iface_opt="-I $ifname"
    case "$method" in
        ping)
            local res=$(ping $iface_opt -c 3 -W "$timeout" "$host" 2>/dev/null)
            if [ $? -eq 0 ]; then
                local lat=$(echo "$res" | grep -oE 'avg[^0-9]*([0-9.]+)' | grep -oE '[0-9.]+' | head -1)
                local loss=$(echo "$res" | grep -oE '[0-9]+% packet loss' | grep -oE '[0-9]+' | head -1)
                echo "{\"state\":\"up\",\"latency\":${lat:-0},\"packet_loss\":${loss:-0},\"host\":\"$host\",\"method\":\"$method\",\"ifname\":\"$ifname\"}"
            else
                echo "{\"state\":\"down\",\"latency\":0,\"packet_loss\":100,\"host\":\"$host\",\"method\":\"$method\",\"ifname\":\"$ifname\"}"
            fi ;;
        http|https)
            local curl_iface=""
            [ -n "$ifname" ] && curl_iface="--interface $ifname"
            local out=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" $curl_iface --connect-timeout "$timeout" --max-time "$timeout" "$host" 2>/dev/null)
            local code=$(echo "$out" | awk '{print $1}')
            local tt=$(echo "$out" | awk '{print $2}')
            if [ "$code" -ge 200 ] && [ "$code" -lt 400 ] 2>/dev/null; then
                local ms=$(awk "BEGIN{printf \"%.0f\", $tt * 1000}")
                echo "{\"state\":\"up\",\"latency\":$ms,\"http_code\":$code,\"host\":\"$host\",\"method\":\"$method\",\"ifname\":\"$ifname\"}"
            else
                echo "{\"state\":\"down\",\"latency\":0,\"http_code\":${code:-0},\"host\":\"$host\",\"method\":\"$method\",\"ifname\":\"$ifname\"}"
            fi ;;
        dns)
            local s=$(date +%s)
            nslookup "$host" >/dev/null 2>&1
            local rc=$? e=$(date +%s) ms=$(( (e - s) * 1000 ))
            [ "$ms" -eq 0 ] && ms=1
            [ $rc -eq 0 ] && echo "{\"state\":\"up\",\"latency\":$ms,\"host\":\"$host\",\"method\":\"$method\"}" || echo "{\"state\":\"down\",\"latency\":0,\"host\":\"$host\",\"method\":\"$method\"}"
            ;;
        *) echo '{"error":"invalid method"}' ;;
    esac
}

handle_get_speed_history() {
    read input
    if [ -f "$SPEED_HISTORY_FILE" ]; then
        echo "{\"speed_history\":$(cat "$SPEED_HISTORY_FILE")}"
    else
        echo '{"speed_history":[]}'
    fi
}

handle_clear_speed_history() {
    echo '[]' > "$SPEED_HISTORY_FILE"
    echo '{"result":"ok"}'
}

handle_run_speed_test() {
    read input
    local ifname=$(echo "$input" | jsonfilter -e '@.ifname' 2>/dev/null || echo "")
    local iface_name=$(echo "$input" | jsonfilter -e '@.iface_name' 2>/dev/null || echo "unknown")
    [ -z "$ifname" ] && { echo '{"error":"ifname required"}'; return; }

    local dl_url=$(uci -q get "$CONF.global.download_url" || echo "")
    local ul_url=$(uci -q get "$CONF.global.upload_url" || echo "")
    local ul_size=$(uci -q get "$CONF.global.upload_size" || echo "5")

    local latency=0
    local ping_res=$(ping -I "$ifname" -c 3 -W 5 8.8.8.8 2>/dev/null)
    if [ $? -eq 0 ]; then
        latency=$(echo "$ping_res" | grep -oE 'avg[^0-9]*([0-9.]+)' | grep -oE '[0-9.]+' | head -1)
        [ -z "$latency" ] && latency="0"
    fi

    local dl_mbps="0.00" ul_mbps="0.00"

    if [ -n "$dl_url" ]; then
        local dl_speed=$(curl -s -L --interface "$ifname" -o /dev/null -w '%{speed_download}' -m 30 "$dl_url" 2>/dev/null)
        if [ -n "$dl_speed" ] && [ "$dl_speed" != "0" ] && [ "$dl_speed" != "0.000" ]; then
            dl_mbps=$(awk "BEGIN{printf \"%.2f\", $dl_speed * 8 / 1000000}" 2>/dev/null || echo "0.00")
        fi
    fi

    if [ -n "$ul_url" ]; then
        local ul_speed=$(dd if=/dev/zero bs=1M count=$ul_size 2>/dev/null | curl -s -L --interface "$ifname" -X POST -d @- -o /dev/null -w '%{speed_upload}' -m 30 "$ul_url" 2>/dev/null)
        if [ -n "$ul_speed" ] && [ "$ul_speed" != "0" ] && [ "$ul_speed" != "0.000" ]; then
            ul_mbps=$(awk "BEGIN{printf \"%.2f\", $ul_speed * 8 / 1000000}" 2>/dev/null || echo "0.00")
        fi
    fi

    local ts=$(date +%s)
    local ti=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")
    local ev="{\"iface\":\"$iface_name\",\"ifname\":\"$ifname\",\"download\":$dl_mbps,\"upload\":$ul_mbps,\"latency\":$latency,\"timestamp\":$ts,\"time\":\"$ti\"}"
    if [ -f "$SPEED_HISTORY_FILE" ] && [ "$(cat "$SPEED_HISTORY_FILE" 2>/dev/null)" != "[]" ]; then
        sed -i "s/\]$/,$ev]/" "$SPEED_HISTORY_FILE" 2>/dev/null || echo "[$ev]" > "$SPEED_HISTORY_FILE"
    else
        echo "[$ev]" > "$SPEED_HISTORY_FILE"
    fi

    local midx=0
    while true; do
        local mname=$(uci -q get "$CONF.@interface[$midx].name")
        [ -z "$mname" ] && break
        local mifname=$(uci -q get "$CONF.@interface[$midx].ifname")
        if [ "$mifname" = "$ifname" ]; then
            echo "$dl_mbps" > "$STATE_DIR/speed_dl_${midx}"
            echo "$ul_mbps" > "$STATE_DIR/speed_ul_${midx}"
            echo "$ts" > "$STATE_DIR/speed_ts_${midx}"
            break
        fi
        midx=$((midx+1))
    done

    echo "{\"result\":\"ok\",\"iface\":\"$iface_name\",\"ifname\":\"$ifname\",\"download\":$dl_mbps,\"upload\":$ul_mbps,\"latency\":$latency}"
}

handle_get_daemon_status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local pid=$(cat "$PID_FILE")
        echo "{\"running\":true,\"pid\":$pid,\"uptime\":0}"
    else
        echo '{"running":false,"pid":0,"uptime":0}'
    fi
}

handle_restart_daemon() {
    /etc/init.d/linkmonitor restart >/dev/null 2>&1
    sleep 1
    [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null && echo '{"result":"ok"}' || echo '{"result":"failed"}'
}

case "$1" in
    list)
        handle_list
        ;;
    call)
        case "$2" in
            get_status) handle_get_status ;;
            get_history) handle_get_history ;;
            clear_history) handle_clear_history ;;
            get_config_summary) handle_get_config_summary ;;
            test_link) handle_test_link ;;
            get_speed_history) handle_get_speed_history ;;
            clear_speed_history) handle_clear_speed_history ;;
            run_speed_test) handle_run_speed_test ;;
            get_daemon_status) handle_get_daemon_status ;;
            restart_daemon) handle_restart_daemon ;;
            *) echo '{"error":"unknown method"}' ;;
        esac
        ;;
esac
RPCDEOF
chmod +x /usr/libexec/rpcd/linkmonitor

# ============================================================
# [4/8] Init Script
# ============================================================
echo "[4/8] Writing init script..."
cat > /etc/init.d/linkmonitor << 'INITEOF'
#!/bin/sh /etc/rc.common
START=95
STOP=10
USE_PROCD=1
PROG=/usr/bin/linkmonitor-daemon

start_service() {
    local enabled
    config_load linkmonitor
    config_get enabled global enabled 1
    [ "$enabled" = "1" ] || return 0
    procd_open_instance
    procd_set_param command "$PROG"
    procd_set_param respawn 3600 5 5
    procd_set_param stdout 0
    procd_set_param stderr 1
    procd_set_param pidfile /var/run/linkmonitor.pid
    procd_close_instance
}

service_triggers() {
    procd_add_reload_trigger "linkmonitor"
}

reload_service() {
    stop
    start
}
INITEOF
chmod +x /etc/init.d/linkmonitor

# ============================================================
# [5/8] LuCI Menu (3 tabs)
# ============================================================
echo "[5/8] Writing LuCI menu..."
cat > /usr/share/luci/menu.d/luci-app-linkmonitor.json << 'MENUEOF'
{
    "admin/network/linkmonitor": {
        "title": "Link Monitor",
        "order": 90,
        "action": { "type": "firstchild" },
        "depends": { "acl": ["luci-app-linkmonitor"], "uci": { "linkmonitor": true } }
    },
    "admin/network/linkmonitor/overview": {
        "title": "Overview",
        "order": 1,
        "action": { "type": "view", "path": "linkmonitor/overview" }
    },
    "admin/network/linkmonitor/speed": {
        "title": "Speed History",
        "order": 2,
        "action": { "type": "view", "path": "linkmonitor/speed" }
    },
    "admin/network/linkmonitor/config": {
        "title": "Configuration",
        "order": 3,
        "action": { "type": "view", "path": "linkmonitor/config" }
    }
}
MENUEOF

# ============================================================
# [6/8] ACL (with new RPC methods)
# ============================================================
echo "[6/8] Writing ACL..."
cat > /usr/share/rpcd/acl.d/luci-app-linkmonitor.json << 'ACLEOF'
{
    "luci-app-linkmonitor": {
        "description": "Grant access to Link Monitor",
        "read": {
            "ubus": { "linkmonitor": ["get_status","get_history","get_config_summary","test_link","get_daemon_status","get_speed_history"] },
            "uci": ["linkmonitor"]
        },
        "write": {
            "ubus": { "linkmonitor": ["clear_history","restart_daemon","test_link","clear_speed_history","run_speed_test"] },
            "uci": ["linkmonitor"]
        }
    }
}
ACLEOF

# ============================================================
# [7/8] LuCI Views
# ============================================================
echo "[7/8] Writing LuCI views..."

# ---- overview.js ----
cat > /www/luci-static/resources/view/linkmonitor/overview.js << 'VIEWEOF'
'use strict';
'require view';
'require dom';
'require poll';
'require rpc';
'require ui';

var callGetStatus = rpc.declare({
	object: 'linkmonitor', method: 'get_status', expect: { status: {} }
});
var callGetHistory = rpc.declare({
	object: 'linkmonitor', method: 'get_history', params: ['limit'], expect: { history: [] }
});
var callGetDaemonStatus = rpc.declare({
	object: 'linkmonitor', method: 'get_daemon_status', expect: {}
});
var callTestLink = rpc.declare({
	object: 'linkmonitor', method: 'test_link', params: ['host', 'method', 'timeout', 'ifname'], expect: {}
});
var callClearHistory = rpc.declare({
	object: 'linkmonitor', method: 'clear_history', expect: {}
});
var callRestartDaemon = rpc.declare({
	object: 'linkmonitor', method: 'restart_daemon', expect: {}
});
var callRunSpeedTest = rpc.declare({
	object: 'linkmonitor', method: 'run_speed_test', params: ['ifname', 'iface_name'], expect: {}
});

function formatTimeSince(ts) {
	if (!ts) return '-';
	var d = Math.floor(Date.now()/1000) - ts;
	if (d < 0) d = 0;
	if (d < 60) return d + 's ago';
	if (d < 3600) return Math.floor(d/60) + 'm ago';
	if (d < 86400) return Math.floor(d/3600) + 'h ago';
	return Math.floor(d/86400) + 'd ago';
}

function stateBadge(state) {
	var c = state === 'up' ? '#4caf50' : state === 'down' ? '#f44336' : '#9e9e9e';
	var l = state === 'up' ? 'UP' : state === 'down' ? 'DOWN' : 'UNKNOWN';
	return E('span', { style: 'display:inline-block;padding:2px 10px;border-radius:12px;color:#fff;font-weight:bold;font-size:12px;background:'+c }, l);
}

function latencyBar(lat) {
	var pct = Math.min((lat/500)*100, 100);
	var c = lat < 50 ? '#4caf50' : lat < 150 ? '#ff9800' : '#f44336';
	return E('div', { style: 'display:flex;align-items:center;gap:8px' }, [
		E('div', { style: 'flex:1;height:8px;background:#e0e0e0;border-radius:4px;overflow:hidden' }, [
			E('div', { style: 'height:100%;width:'+pct+'%;background:'+c+';border-radius:4px;transition:width .3s' })
		]),
		E('span', { style: 'font-size:12px;min-width:55px' }, lat + ' ms')
	]);
}

function speedBar(mbps, maxMbps, color) {
	maxMbps = maxMbps || 100;
	var pct = Math.min((mbps / maxMbps) * 100, 100);
	return E('div', { style: 'display:flex;align-items:center;gap:8px' }, [
		E('div', { style: 'flex:1;height:8px;background:#e0e0e0;border-radius:4px;overflow:hidden' }, [
			E('div', { style: 'height:100%;width:'+pct+'%;background:'+(color||'#2196f3')+';border-radius:4px;transition:width .3s' })
		]),
		E('span', { style: 'font-size:12px;min-width:70px;font-weight:bold' }, mbps.toFixed(2) + ' Mbps')
	]);
}

return view.extend({
	title: _('Link Monitor'),

	load: function() {
		return Promise.all([callGetStatus(), callGetHistory(50), callGetDaemonStatus()]);
	},

	render: function(data) {
		var status = data[0] || {}, history = (data[1] || []).reverse(), daemon = data[2] || {};
		var self = this;

		/* Daemon status bar */
		var daemonBar = E('div', {
			style: 'display:flex;align-items:center;gap:16px;padding:12px 16px;margin-bottom:16px;border-radius:8px;background:'+(daemon.running?'#e8f5e9':'#ffebee')+';border:1px solid '+(daemon.running?'#a5d6a7':'#ef9a9a')
		}, [
			E('span', { style: 'width:12px;height:12px;border-radius:50%;background:'+(daemon.running?'#4caf50':'#f44336') }),
			E('span', { style: 'font-weight:bold' }, daemon.running ? _('Daemon Running') : _('Daemon Stopped')),
			daemon.running ? E('span', { style: 'color:#666;font-size:13px' }, 'PID: '+(daemon.pid||0)) : '',
			E('div', { style: 'margin-left:auto' }, [
				E('button', { 'class': 'cbi-button cbi-button-action', click: function() {
					callRestartDaemon().then(function(r) {
						ui.addNotification(null, E('p', {}, r.result==='ok' ? _('Daemon restarted.') : _('Failed.')));
						window.setTimeout(function() { window.location.reload(); }, 1500);
					});
				}}, daemon.running ? _('Restart') : _('Start'))
			])
		]);

		/* Interface cards */
		var cards = [];
		var keys = Object.keys(status);
		if (!keys.length)
			cards.push(E('div', { style: 'padding:32px;text-align:center;color:#999' }, _('No interfaces configured. Go to Configuration to add interfaces.')));

		/* Find max speed for bar scaling */
		var maxDl = 1, maxUl = 1;
		for (var ki = 0; ki < keys.length; ki++) {
			var si = status[keys[ki]];
			if ((si.download || 0) > maxDl) maxDl = si.download;
			if ((si.upload || 0) > maxUl) maxUl = si.upload;
		}
		var maxSpeed = Math.max(maxDl, maxUl, 10);

		for (var i = 0; i < keys.length; i++) {
			var lk = status[keys[i]];
			var bc = lk.state==='up' ? '#4caf50' : lk.state==='down' ? '#f44336' : '#9e9e9e';
			var dl = parseFloat(lk.download) || 0;
			var ul = parseFloat(lk.upload) || 0;
			var hasSpeed = (dl > 0 || ul > 0);

			cards.push(E('div', {
				style: 'border:1px solid #ddd;border-left:4px solid '+bc+';border-radius:8px;padding:16px;margin-bottom:12px;background:#fff'
			}, [
				/* Header: name, interface, state, buttons */
				E('div', { style: 'display:flex;justify-content:space-between;align-items:center;margin-bottom:12px' }, [
					E('div', {}, [
						E('h3', { style: 'margin:0 0 4px 0;font-size:16px' }, lk.name || 'Interface '+(parseInt(keys[i])+1)),
						E('span', { style: 'color:#666;font-size:13px' }, [
							lk.host + ' (' + (lk.method||'ping') + ')',
							lk.ifname ? E('span', { style: 'margin-left:8px;padding:1px 6px;background:#e3f2fd;border-radius:4px;font-size:11px;color:#1565c0' }, lk.ifname) : '',
							lk.uci_iface ? E('span', { style: 'margin-left:4px;padding:1px 6px;background:#f3e5f5;border-radius:4px;font-size:11px;color:#7b1fa2' }, lk.uci_iface) : ''
						])
					]),
					E('div', { style: 'display:flex;align-items:center;gap:8px' }, [
						stateBadge(lk.state),
						E('button', { 'class': 'cbi-button cbi-button-action', style: 'font-size:12px;padding:2px 8px',
							'data-h': lk.host, 'data-m': lk.method||'ping', 'data-if': lk.ifname||'',
							click: function(ev) {
								var h=ev.target.getAttribute('data-h'), m=ev.target.getAttribute('data-m'), ifn=ev.target.getAttribute('data-if');
								ui.showModal(_('Testing'), [E('p', { 'class': 'spinning' }, _('Testing %s...').format(h))]);
								callTestLink(h, m, 5, ifn).then(function(r) {
									ui.hideModal();
									ui.showModal(_('Result'), [
										E('p', {}, [E('strong', {}, 'State: '), stateBadge(r.state||'unknown')]),
										E('p', {}, [E('strong', {}, 'Latency: '), (r.latency||0)+' ms']),
										r.packet_loss!==undefined ? E('p', {}, [E('strong', {}, 'Loss: '), r.packet_loss+'%']) : '',
										r.http_code!==undefined ? E('p', {}, [E('strong', {}, 'HTTP: '), String(r.http_code)]) : '',
										E('div', { 'class': 'right' }, [E('button', { 'class': 'cbi-button', click: ui.hideModal }, _('Close'))])
									]);
								});
							}
						}, _('Test')),
						lk.ifname ? E('button', { 'class': 'cbi-button cbi-button-action', style: 'font-size:12px;padding:2px 8px;background:#2196f3;border-color:#1976d2;color:#fff',
							'data-ifname': lk.ifname, 'data-iname': lk.name,
							click: function(ev) {
								var ifn=ev.target.getAttribute('data-ifname'), iname=ev.target.getAttribute('data-iname');
								ui.showModal(_('Speed Test'), [E('p', { 'class': 'spinning' }, _('Running speed test on %s (%s)... This may take up to 60 seconds.').format(iname, ifn))]);
								callRunSpeedTest(ifn, iname).then(function(r) {
									ui.hideModal();
									if (r.error) {
										ui.showModal(_('Error'), [E('p', {}, r.error), E('div', { 'class': 'right' }, [E('button', { 'class': 'cbi-button', click: ui.hideModal }, _('Close'))])]);
									} else {
										ui.showModal(_('Speed Test Result'), [
											E('p', {}, [E('strong', {}, 'Interface: '), (r.iface||iname) + ' (' + (r.ifname||ifn) + ')']),
											E('p', {}, [E('strong', {}, 'Download: '), E('span', { style: 'color:#2196f3;font-weight:bold' }, (r.download||0) + ' Mbps')]),
											E('p', {}, [E('strong', {}, 'Upload: '), E('span', { style: 'color:#ff9800;font-weight:bold' }, (r.upload||0) + ' Mbps')]),
											E('p', {}, [E('strong', {}, 'Latency: '), (r.latency||0) + ' ms']),
											E('div', { 'class': 'right' }, [E('button', { 'class': 'cbi-button', click: function() { ui.hideModal(); window.location.reload(); } }, _('Close'))])
										]);
									}
								});
							}
						}, _('Speed Test')) : ''
					])
				]),
				/* Stats grid */
				E('div', { style: 'display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px' }, [
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Latency')), latencyBar(lk.latency||0)]),
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Download')), speedBar(dl, maxSpeed, '#2196f3')]),
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Upload')), speedBar(ul, maxSpeed, '#ff9800')]),
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Last Check')), E('span', {}, formatTimeSince(lk.last_check))]),
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Last Change')), E('span', {}, formatTimeSince(lk.last_change))]),
					E('div', {}, [E('div', { style: 'font-size:12px;color:#999;margin-bottom:4px' }, _('Fails')), E('span', { style: 'font-weight:bold;color:'+((lk.consecutive_fails>0)?'#f44336':'#4caf50') }, String(lk.consecutive_fails||0))])
				]),
				/* Speed test timestamp */
				hasSpeed ? E('div', { style: 'margin-top:8px;font-size:11px;color:#999;text-align:right' }, _('Speed test: ') + formatTimeSince(lk.speed_timestamp)) : ''
			]));
		}

		/* History table */
		var hrows = [];
		for (var j = 0; j < history.length && j < 50; j++) {
			var ev = history[j];
			hrows.push(E('tr', {}, [
				E('td', { style: 'padding:6px 12px' }, ev.time||'-'),
				E('td', { style: 'padding:6px 12px' }, ev.name||'-'),
				E('td', { style: 'padding:6px 12px' }, ev.host||'-'),
				E('td', { style: 'padding:6px 12px' }, ev.ifname ? E('span', { style: 'padding:1px 6px;background:#e3f2fd;border-radius:4px;font-size:11px;color:#1565c0' }, ev.ifname) : '-'),
				E('td', { style: 'padding:6px 12px' }, stateBadge(ev.state)),
				E('td', { style: 'padding:6px 12px' }, (ev.latency||0)+' ms')
			]));
		}

		return E('div', {}, [
			E('h2', {}, _('Link Monitor - Overview')),
			daemonBar,
			E('h3', { style: 'margin-top:24px' }, _('Monitored Interfaces')),
			E('div', {}, cards),
			E('div', { style: 'display:flex;justify-content:space-between;align-items:center;margin-top:24px' }, [
				E('h3', { style: 'margin:0' }, _('Event History')),
				E('button', { 'class': 'cbi-button cbi-button-negative', click: function() {
					ui.showModal(_('Clear History'), [
						E('p', {}, _('Clear all monitoring history?')),
						E('div', { 'class': 'right' }, [
							E('button', { 'class': 'cbi-button', click: ui.hideModal }, _('Cancel')), ' ',
							E('button', { 'class': 'cbi-button cbi-button-negative', click: function() {
								ui.hideModal(); callClearHistory().then(function() { window.location.reload(); });
							}}, _('Clear'))
						])
					]);
				}}, _('Clear History'))
			]),
			E('div', { style: 'margin-top:8px;overflow-x:auto' },
				E('table', { 'class': 'table', style: 'width:100%;border-collapse:collapse' }, [
					E('thead', {}, [E('tr', { style: 'background:#f5f5f5' }, [
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Time')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Interface')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Host')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Device')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('State')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Latency'))
					])]),
					E('tbody', {}, hrows.length ? hrows : [E('tr', {}, [E('td', { colspan: '6', style: 'padding:16px;text-align:center;color:#999' }, _('No events yet.'))])])
				])
			)
		]);
	},

	handleSaveApply: null, handleSave: null, handleReset: null
});
VIEWEOF

# ---- speed.js (NEW - Speed History tab) ----
cat > /www/luci-static/resources/view/linkmonitor/speed.js << 'SPEEDEOF'
'use strict';
'require view';
'require dom';
'require rpc';
'require ui';

var callGetSpeedHistory = rpc.declare({
	object: 'linkmonitor', method: 'get_speed_history', params: ['limit'], expect: { speed_history: [] }
});
var callClearSpeedHistory = rpc.declare({
	object: 'linkmonitor', method: 'clear_speed_history', expect: {}
});

function speedBarInline(mbps, maxMbps, color) {
	maxMbps = maxMbps || 100;
	if (maxMbps < 1) maxMbps = 1;
	var pct = Math.min((mbps / maxMbps) * 100, 100);
	return E('div', { style: 'display:flex;align-items:center;gap:6px;min-width:150px' }, [
		E('div', { style: 'flex:1;height:10px;background:#e0e0e0;border-radius:5px;overflow:hidden;min-width:80px' }, [
			E('div', { style: 'height:100%;width:'+pct+'%;background:'+(color||'#2196f3')+';border-radius:5px;transition:width .3s' })
		]),
		E('span', { style: 'font-size:12px;min-width:70px;font-weight:bold' }, mbps.toFixed(2))
	]);
}

return view.extend({
	title: _('Speed History'),

	load: function() {
		return callGetSpeedHistory(500);
	},

	render: function(data) {
		var history = (data || []).slice().reverse();
		var self = this;

		/* Gather unique interface names for filter */
		var ifaces = {};
		for (var i = 0; i < history.length; i++) {
			var ifn = history[i].iface || history[i].ifname || 'unknown';
			ifaces[ifn] = true;
		}
		var ifaceList = Object.keys(ifaces).sort();

		/* Find max values for bar scaling */
		var maxDl = 1, maxUl = 1;
		for (var i = 0; i < history.length; i++) {
			if ((history[i].download || 0) > maxDl) maxDl = history[i].download;
			if ((history[i].upload || 0) > maxUl) maxUl = history[i].upload;
		}
		var maxSpeed = Math.max(maxDl, maxUl, 1);

		/* Filter dropdown */
		var filterSelect = E('select', { style: 'margin-left:16px;padding:4px 8px;border:1px solid #ccc;border-radius:4px', change: function(ev) {
			var val = ev.target.value;
			var rows = document.querySelectorAll('tr[data-iface]');
			for (var r = 0; r < rows.length; r++) {
				if (val === 'all' || rows[r].getAttribute('data-iface') === val) {
					rows[r].style.display = '';
				} else {
					rows[r].style.display = 'none';
				}
			}
		}}, [
			E('option', { value: 'all' }, _('All Interfaces'))
		].concat(ifaceList.map(function(n) {
			return E('option', { value: n }, n);
		})));

		/* Build rows */
		var rows = [];
		for (var j = 0; j < history.length; j++) {
			var ev = history[j];
			var ifaceName = ev.iface || ev.ifname || 'unknown';
			rows.push(E('tr', { 'data-iface': ifaceName }, [
				E('td', { style: 'padding:6px 12px;white-space:nowrap' }, ev.time || '-'),
				E('td', { style: 'padding:6px 12px' }, [
					E('span', { style: 'font-weight:bold' }, ifaceName),
					ev.ifname && ev.iface ? E('span', { style: 'margin-left:4px;padding:1px 6px;background:#e3f2fd;border-radius:4px;font-size:11px;color:#1565c0' }, ev.ifname) : ''
				]),
				E('td', { style: 'padding:6px 12px' }, speedBarInline(parseFloat(ev.download)||0, maxSpeed, '#2196f3')),
				E('td', { style: 'padding:6px 12px' }, speedBarInline(parseFloat(ev.upload)||0, maxSpeed, '#ff9800')),
				E('td', { style: 'padding:6px 12px' }, (parseFloat(ev.latency)||0).toFixed(1) + ' ms')
			]));
		}

		return E('div', {}, [
			E('h2', {}, _('Link Monitor - Speed History')),
			E('div', { style: 'display:flex;align-items:center;justify-content:space-between;margin-bottom:16px' }, [
				E('div', { style: 'display:flex;align-items:center' }, [
					E('span', { style: 'font-weight:bold' }, _('Filter: ')),
					filterSelect
				]),
				E('div', { style: 'display:flex;gap:8px' }, [
					E('button', { 'class': 'cbi-button cbi-button-negative', click: function() {
						ui.showModal(_('Clear Speed History'), [
							E('p', {}, _('Clear all speed test history data?')),
							E('div', { 'class': 'right' }, [
								E('button', { 'class': 'cbi-button', click: ui.hideModal }, _('Cancel')), ' ',
								E('button', { 'class': 'cbi-button cbi-button-negative', click: function() {
									ui.hideModal();
									callClearSpeedHistory().then(function() { window.location.reload(); });
								}}, _('Clear'))
							])
						]);
					}}, _('Clear Speed History'))
				])
			]),
			/* Summary stats */
			ifaceList.length > 0 ? E('div', { style: 'display:flex;gap:16px;flex-wrap:wrap;margin-bottom:16px' }, ifaceList.map(function(iface) {
				/* Find latest entry for this interface */
				var latest = null;
				for (var si = 0; si < history.length; si++) {
					if ((history[si].iface || history[si].ifname) === iface) { latest = history[si]; break; }
				}
				if (!latest) return '';
				return E('div', { style: 'border:1px solid #ddd;border-radius:8px;padding:12px 16px;background:#fff;min-width:200px' }, [
					E('div', { style: 'font-weight:bold;margin-bottom:8px;font-size:14px' }, iface),
					E('div', { style: 'display:flex;gap:16px;font-size:13px' }, [
						E('div', {}, [
							E('span', { style: 'color:#999' }, 'DL: '),
							E('span', { style: 'color:#2196f3;font-weight:bold' }, (parseFloat(latest.download)||0).toFixed(2) + ' Mbps')
						]),
						E('div', {}, [
							E('span', { style: 'color:#999' }, 'UL: '),
							E('span', { style: 'color:#ff9800;font-weight:bold' }, (parseFloat(latest.upload)||0).toFixed(2) + ' Mbps')
						]),
						E('div', {}, [
							E('span', { style: 'color:#999' }, 'Lat: '),
							E('span', {}, (parseFloat(latest.latency)||0).toFixed(1) + ' ms')
						])
					])
				]);
			})) : '',
			/* Table */
			E('div', { style: 'overflow-x:auto' },
				E('table', { 'class': 'table', style: 'width:100%;border-collapse:collapse' }, [
					E('thead', {}, [E('tr', { style: 'background:#f5f5f5' }, [
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Time')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Interface')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Download (Mbps)')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Upload (Mbps)')),
						E('th', { style: 'padding:8px 12px;text-align:left' }, _('Latency'))
					])]),
					E('tbody', {}, rows.length ? rows : [E('tr', {}, [E('td', { colspan: '5', style: 'padding:16px;text-align:center;color:#999' }, _('No speed test data yet. Enable speed tests in Configuration and wait for the first test, or run a manual test from the Overview tab.'))])])
				])
			)
		]);
	},

	handleSaveApply: null, handleSave: null, handleReset: null
});
SPEEDEOF

# ---- config.js (enhanced with interface sections, speed, telegram) ----
cat > /www/luci-static/resources/view/linkmonitor/config.js << 'CFGEOF'
'use strict';
'require view';
'require form';
'require uci';

return view.extend({
	title: _('Link Monitor - Configuration'),
	load: function() { return uci.load('linkmonitor'); },
	render: function() {
		var m, s, o;
		m = new form.Map('linkmonitor', _('Link Monitor Configuration'),
			_('Configure WAN interfaces to monitor, speed test settings, and alert rules including Telegram notifications.'));

		/* ===== Global Settings ===== */
		s = m.section(form.NamedSection, 'global', 'global', _('Global Settings'));
		s.anonymous = false;

		o = s.option(form.Flag, 'enabled', _('Enable Monitoring'),
			_('Enable or disable the link monitoring daemon.'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Value, 'interval', _('Check Interval (seconds)'),
			_('Default interval between link checks. Interfaces can override.'));
		o.datatype = 'uinteger';
		o.default = '30';
		o.placeholder = '30';

		o = s.option(form.Value, 'history_size', _('Event History Size'),
			_('Maximum number of link state events to keep.'));
		o.datatype = 'uinteger';
		o.default = '200';
		o.placeholder = '200';

		o = s.option(form.Flag, 'speed_enabled', _('Enable Speed Tests'),
			_('Enable periodic download/upload speed tests per interface.'));
		o.default = '0';

		o = s.option(form.Value, 'speed_interval', _('Speed Test Interval (seconds)'),
			_('Time between automatic speed tests. Recommended: 1800 (30min) or higher.'));
		o.datatype = 'uinteger';
		o.default = '1800';
		o.placeholder = '1800';
		o.depends('speed_enabled', '1');

		o = s.option(form.Value, 'download_url', _('Download Test URL'),
			_('URL of a file to download for speed testing (e.g. http://proof.ovh.net/files/10Mb.dat).'));
		o.placeholder = 'http://proof.ovh.net/files/10Mb.dat';
		o.depends('speed_enabled', '1');

		o = s.option(form.Value, 'upload_url', _('Upload Test URL'),
			_('URL accepting POST data for upload test (e.g. http://devnull-as-a-service.com/dev/null).'));
		o.placeholder = 'http://devnull-as-a-service.com/dev/null';
		o.depends('speed_enabled', '1');

		o = s.option(form.Value, 'upload_size', _('Upload Size (MB)'),
			_('Size of data to upload for speed test.'));
		o.datatype = 'uinteger';
		o.default = '5';
		o.placeholder = '5';
		o.depends('speed_enabled', '1');

		o = s.option(form.Value, 'speed_history_size', _('Speed History Size'),
			_('Maximum number of speed test records to keep.'));
		o.datatype = 'uinteger';
		o.default = '500';
		o.placeholder = '500';
		o.depends('speed_enabled', '1');

		/* ===== Monitored Interfaces ===== */
		s = m.section(form.TableSection, 'interface', _('Monitored Interfaces'),
			_('Configure WAN interfaces to monitor. Each interface is checked independently.'));
		s.anonymous = true;
		s.addremove = true;
		s.sortable = true;
		s.addbtntitle = _('Add Interface');

		o = s.option(form.Flag, 'enabled', _('On'));
		o.default = '1';
		o.editable = true;

		o = s.option(form.Value, 'name', _('Name'),
			_('Descriptive name for this interface.'));
		o.rmempty = false;
		o.placeholder = _('e.g. WAN');

		o = s.option(form.Value, 'ifname', _('Device'),
			_('Physical network device (e.g. eth1, lan5). Leave empty to auto-detect from UCI.'));
		o.placeholder = _('e.g. eth1');
		o.optional = true;

		o = s.option(form.Value, 'uci_iface', _('UCI Interface'),
			_('UCI network interface name (e.g. wan, secondwan). Used for device auto-detection.'));
		o.placeholder = _('e.g. wan');
		o.optional = true;

		o = s.option(form.Value, 'host', _('Host / URL'),
			_('Target to check (IP, hostname, or URL).'));
		o.rmempty = false;
		o.placeholder = _('e.g. 8.8.8.8');

		o = s.option(form.ListValue, 'method', _('Method'));
		o.value('ping', _('Ping'));
		o.value('http', _('HTTP/S'));
		o.value('dns', _('DNS'));
		o.default = 'ping';

		o = s.option(form.Value, 'interval', _('Interval'));
		o.datatype = 'uinteger';
		o.optional = true;
		o.placeholder = _('global');

		o = s.option(form.Value, 'timeout', _('Timeout'));
		o.datatype = 'uinteger';
		o.default = '5';

		o = s.option(form.Value, 'retries', _('Retries'));
		o.datatype = 'uinteger';
		o.default = '3';
		o.depends('method', 'ping');

		o = s.option(form.Flag, 'speed_test', _('Speed'),
			_('Enable speed tests on this interface.'));
		o.default = '0';
		o.editable = true;

		/* ===== Alert Rules ===== */
		s = m.section(form.TableSection, 'alert', _('Alert Rules'),
			_('Configure alert actions for link state changes and speed degradation.'));
		s.anonymous = true;
		s.addremove = true;
		s.sortable = true;
		s.addbtntitle = _('Add Alert');

		o = s.option(form.Flag, 'enabled', _('On'));
		o.default = '1';
		o.editable = true;

		o = s.option(form.Value, 'name', _('Name'));
		o.rmempty = false;

		o = s.option(form.ListValue, 'type', _('Type'));
		o.value('syslog', _('Syslog'));
		o.value('telegram', _('Telegram'));
		o.value('email', _('Email'));
		o.value('script', _('Script'));
		o.value('webhook', _('Webhook'));
		o.default = 'syslog';

		o = s.option(form.ListValue, 'trigger', _('Trigger'));
		o.value('both', _('Both'));
		o.value('down', _('Down Only'));
		o.value('up', _('Up Only'));
		o.default = 'both';

		/* Telegram options */
		o = s.option(form.Value, 'bot_token', _('Bot Token'),
			_('Telegram Bot API token from @BotFather.'));
		o.depends('type', 'telegram');
		o.optional = true;
		o.password = true;

		o = s.option(form.Value, 'chat_id', _('Chat ID'),
			_('Telegram chat/group ID for notifications.'));
		o.depends('type', 'telegram');
		o.optional = true;

		o = s.option(form.Flag, 'notify_speed', _('Speed Alerts'),
			_('Send alert when speed drops below threshold.'));
		o.depends('type', 'telegram');
		o.default = '0';

		o = s.option(form.Value, 'speed_threshold', _('Threshold (Mbps)'),
			_('Alert when download speed falls below this value.'));
		o.datatype = 'ufloat';
		o.depends('type', 'telegram');
		o.optional = true;
		o.placeholder = '10';

		/* Email options */
		o = s.option(form.Value, 'recipient', _('Email'));
		o.depends('type', 'email');
		o.optional = true;

		o = s.option(form.Value, 'subject_prefix', _('Prefix'));
		o.depends('type', 'email');
		o.optional = true;
		o.placeholder = '[LinkMonitor]';

		/* Script options */
		o = s.option(form.Value, 'path', _('Script Path'));
		o.depends('type', 'script');
		o.optional = true;

		/* Webhook options */
		o = s.option(form.Value, 'url', _('Webhook URL'));
		o.depends('type', 'webhook');
		o.optional = true;

		return m.render();
	}
});
CFGEOF

# ============================================================
# [8/8] Activate services
# ============================================================
echo "[8/8] Activating services..."

# Clean old state files
rm -f /tmp/linkmonitor/link_*.json 2>/dev/null
rm -f /tmp/linkmonitor/lastcheck_* 2>/dev/null
rm -f /tmp/linkmonitor/prevstate_* 2>/dev/null
rm -f /tmp/linkmonitor/fails_* 2>/dev/null
rm -f /tmp/linkmonitor/lastchange_* 2>/dev/null
rm -f /tmp/linkmonitor/lastspeed_* 2>/dev/null
echo '{}' > /tmp/linkmonitor/status.json
echo '[]' > /tmp/linkmonitor/history.json
echo '[]' > /tmp/linkmonitor/speed_history.json

/etc/init.d/rpcd reload 2>/dev/null
/etc/init.d/linkmonitor enable 2>/dev/null
/etc/init.d/linkmonitor start 2>/dev/null

sleep 2

echo ""
echo "========================================="
echo " luci-app-linkmonitor v2.0.0 INSTALLED!"
echo "========================================="
echo " Features:"
echo "   - Multi-WAN interface monitoring"
echo "   - Per-interface speed tests (DL+UL)"
echo "   - Speed history with visual bars"
echo "   - Telegram bot alerts"
echo "   - Speed degradation alerts"
echo ""
echo " Open LuCI -> Network -> Link Monitor"
echo "   Tab 1: Overview (dashboard)"
echo "   Tab 2: Speed History"
echo "   Tab 3: Configuration"
echo ""
echo " Daemon PID: $(cat /var/run/linkmonitor.pid 2>/dev/null || echo 'starting...')"
echo " Configured interfaces:"
idx=0
while true; do
    iname=$(uci -q get linkmonitor.@interface[$idx].name)
    [ -z "$iname" ] && break
    ifn=$(uci -q get linkmonitor.@interface[$idx].ifname)
    en=$(uci -q get linkmonitor.@interface[$idx].enabled)
    sp=$(uci -q get linkmonitor.@interface[$idx].speed_test)
    echo "   [$idx] $iname ($ifn) enabled=$en speed=$sp"
    idx=$((idx+1))
done
echo "========================================="
