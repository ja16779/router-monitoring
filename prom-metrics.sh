#!/bin/sh
# Metricas personalizadas OpenWrt para node_exporter textfile collector
OUTFILE=/tmp/prom-metrics/openwrt.prom
STATEDIR=/tmp/prom-state
mkdir -p /tmp/prom-metrics "$STATEDIR"

{
# ============================================================
# WiFi — clientes por interfaz/SSID
# ============================================================
printf '# HELP openwrt_wifi_stations Clientes WiFi asociados\n'
printf '# TYPE openwrt_wifi_stations gauge\n'
for iface in phy0-ap0 phy0-ap1 phy1-ap0 phy1-ap1; do
  cnt=$(iw dev "$iface" station dump 2>/dev/null | grep -c '^Station')
  ssid=$(iw dev "$iface" info 2>/dev/null | awk '/ssid/{print $2}')
  [ -z "$ssid" ] && ssid="unknown"
  printf 'openwrt_wifi_stations{interface="%s",ssid="%s"} %s\n' "$iface" "$ssid" "$cnt"
done

# ============================================================
# WiFi — señal, bitrate y tráfico por cliente
# ============================================================
printf '# HELP openwrt_wifi_station_signal_dbm Senal del cliente WiFi en dBm\n'
printf '# TYPE openwrt_wifi_station_signal_dbm gauge\n'
printf '# HELP openwrt_wifi_station_tx_bitrate_mbps Velocidad TX en Mbps\n'
printf '# TYPE openwrt_wifi_station_tx_bitrate_mbps gauge\n'
printf '# HELP openwrt_wifi_station_rx_bitrate_mbps Velocidad RX en Mbps\n'
printf '# TYPE openwrt_wifi_station_rx_bitrate_mbps gauge\n'
printf '# HELP openwrt_wifi_station_tx_bytes_total Bytes TX al cliente\n'
printf '# TYPE openwrt_wifi_station_tx_bytes_total counter\n'
printf '# HELP openwrt_wifi_station_rx_bytes_total Bytes RX del cliente\n'
printf '# TYPE openwrt_wifi_station_rx_bytes_total counter\n'
printf '# HELP openwrt_wifi_station_inactive_ms Tiempo inactivo del cliente en ms\n'
printf '# TYPE openwrt_wifi_station_inactive_ms gauge\n'

# Leer leases para lookup mac->ip,hostname
LEASES=$(cat /tmp/dhcp.leases 2>/dev/null)

for iface in phy0-ap0 phy0-ap1 phy1-ap0 phy1-ap1; do
  iw dev "$iface" station dump 2>/dev/null | awk -v IFACE="$iface" -v LEASES="$LEASES" '
    BEGIN {
      n = split(LEASES, lines, "\n")
      for (i = 1; i <= n; i++) {
        split(lines[i], f, " ")
        if (f[2] != "") {
          lip[f[2]]  = f[3]
          lhost[f[2]] = (f[4] == "*" || f[4] == "") ? f[2] : f[4]
        }
      }
    }
    /^Station/ {
      mac  = $2
      ip   = (mac in lip)   ? lip[mac]   : "unknown"
      host = (mac in lhost) ? lhost[mac] : mac
    }
    /^\tinactive time:/ {
      printf "openwrt_wifi_station_inactive_ms{interface=\"%s\",mac=\"%s\",ip=\"%s\",hostname=\"%s\"} %s\n", IFACE, mac, ip, host, $3
    }
    /^\tsignal:/ {
      printf "openwrt_wifi_station_signal_dbm{interface=\"%s\",mac=\"%s\",ip=\"%s\",hostname=\"%s\"} %s\n", IFACE, mac, ip, host, $2
    }
    /^\ttx bytes:/ {
      printf "openwrt_wifi_station_tx_bytes_total{interface=\"%s\",mac=\"%s\",ip=\"%s\",hostname=\"%s\"} %s\n", IFACE, mac, ip, host, $3
    }
    /^\trx bytes:/ {
      printf "openwrt_wifi_station_rx_bytes_total{interface=\"%s\",mac=\"%s\",ip=\"%s\",hostname=\"%s\"} %s\n", IFACE, mac, ip, host, $3
    }
    /^\ttx bitrate:/ {
      printf "openwrt_wifi_station_tx_bitrate_mbps{interface=\"%s\",mac=\"%s\",ip=\"%s\",hostname=\"%s\"} %s\n", IFACE, mac, ip, host, $3
    }
    /^\trx bitrate:/ {
      printf "openwrt_wifi_station_rx_bitrate_mbps{interface=\"%s\",mac=\"%s\",ip=\"%s\",hostname=\"%s\"} %s\n", IFACE, mac, ip, host, $3
    }
  '
done

# ============================================================
# mwan3 — estado, uptime y conteo de caidas
# ============================================================
printf '# HELP openwrt_mwan3_online Estado WAN mwan3 (1=online 0=offline)\n'
printf '# TYPE openwrt_mwan3_online gauge\n'
printf '# HELP openwrt_mwan3_uptime_seconds Segundos que lleva online la interfaz WAN\n'
printf '# TYPE openwrt_mwan3_uptime_seconds gauge\n'
printf '# HELP openwrt_mwan3_failovers_total Numero de caidas detectadas desde el boot\n'
printf '# TYPE openwrt_mwan3_failovers_total counter\n'
printf '# HELP openwrt_mwan3_last_down_timestamp_seconds Timestamp Unix de la ultima caida\n'
printf '# TYPE openwrt_mwan3_last_down_timestamp_seconds gauge\n'
printf '# HELP openwrt_mwan3_last_down_duration_seconds Duracion en segundos de la ultima caida\n'
printf '# TYPE openwrt_mwan3_last_down_duration_seconds gauge\n'

NOW=$(date +%s)
MWAN=$(mwan3 status 2>/dev/null)

for iface in wan secondwan; do
  # Determinar estado actual
  if echo "$MWAN" | grep -q "interface $iface is online"; then
    state=1
    # Parsear tiempo online "online 00h:36m:22s" → segundos
    uptime_s=$(echo "$MWAN" | grep "interface $iface is online" | \
      grep -oE '[0-9]+h:[0-9]+m:[0-9]+s' | head -1 | \
      tr -s 'hms:' '    ' | awk '{print $1*3600+$2*60+$3+0}')
  else
    state=0
    uptime_s=0
  fi

  printf 'openwrt_mwan3_online{interface="%s"} %s\n' "$iface" "$state"
  printf 'openwrt_mwan3_uptime_seconds{interface="%s"} %s\n' "$iface" "$uptime_s"

  # Tracking de caidas: comparar con estado anterior
  STATEFILE="$STATEDIR/mwan3_${iface}"
  FAILFILE="$STATEDIR/mwan3_${iface}_fails"
  DOWNFILE="$STATEDIR/mwan3_${iface}_downtime"

  prev_state=$(cat "$STATEFILE" 2>/dev/null || echo "1")
  fail_count=$(cat "$FAILFILE"  2>/dev/null || echo "0")
  last_down=$(cat "${DOWNFILE}_ts"  2>/dev/null || echo "0")
  last_dur=$(cat  "${DOWNFILE}_dur" 2>/dev/null || echo "0")

  if [ "$prev_state" = "1" ] && [ "$state" = "0" ]; then
    # Transicion online -> offline: registrar caida
    fail_count=$(( fail_count + 1 ))
    echo "$fail_count" > "$FAILFILE"
    echo "$NOW" > "${DOWNFILE}_ts"
    last_down=$NOW
    last_dur=0
  elif [ "$prev_state" = "0" ] && [ "$state" = "1" ]; then
    # Transicion offline -> online: calcular duracion
    if [ "$last_down" -gt 0 ]; then
      last_dur=$(( NOW - last_down ))
      echo "$last_dur" > "${DOWNFILE}_dur"
    fi
  fi

  echo "$state" > "$STATEFILE"

  printf 'openwrt_mwan3_failovers_total{interface="%s"} %s\n' "$iface" "$fail_count"
  printf 'openwrt_mwan3_last_down_timestamp_seconds{interface="%s"} %s\n' "$iface" "$last_down"
  printf 'openwrt_mwan3_last_down_duration_seconds{interface="%s"} %s\n' "$iface" "$last_dur"
done

# ============================================================
# WAN — latencia ping por interfaz
# ============================================================
printf '# HELP openwrt_wan_ping_ms Latencia ping a 8.8.8.8 por WAN en ms\n'
printf '# TYPE openwrt_wan_ping_ms gauge\n'
for iface in wan secondwan; do
  lat=$(mwan3 use "$iface" sh -c 'ping -c 3 -W 2 8.8.8.8 2>/dev/null | tail -1' 2>/dev/null | grep -oE '[0-9]+\.[0-9]+/[0-9]+\.[0-9]+' | cut -d/ -f2)
  [ -z "$lat" ] && lat="-1"
  printf 'openwrt_wan_ping_ms{interface="%s"} %s\n' "$iface" "$lat"
done

# ============================================================
# AdGuardHome — estadísticas DNS
# ============================================================
printf '# HELP openwrt_adguard_queries_total Consultas DNS totales\n'
printf '# TYPE openwrt_adguard_queries_total gauge\n'
printf '# HELP openwrt_adguard_blocked_total Consultas DNS bloqueadas\n'
printf '# TYPE openwrt_adguard_blocked_total gauge\n'
printf '# HELP openwrt_adguard_avg_processing_ms Latencia DNS promedio en ms\n'
printf '# TYPE openwrt_adguard_avg_processing_ms gauge\n'
AGH=$(curl -s http://127.0.0.1:3000/control/stats 2>/dev/null)
if [ -n "$AGH" ]; then
  q=$(echo "$AGH" | jsonfilter -e '@.num_dns_queries' 2>/dev/null)
  b=$(echo "$AGH" | jsonfilter -e '@.num_blocked_filtering' 2>/dev/null)
  t=$(echo "$AGH" | jsonfilter -e '@.avg_processing_time' 2>/dev/null)
  printf 'openwrt_adguard_queries_total %s\n' "${q:-0}"
  printf 'openwrt_adguard_blocked_total %s\n' "${b:-0}"
  awk "BEGIN{printf \"openwrt_adguard_avg_processing_ms %.4f\n\", ${t:-0}*1000}"
fi

# ============================================================
# Unbound — estadísticas de resolución recursiva
# ============================================================
printf '# HELP openwrt_unbound_queries_total Total de consultas procesadas\n'
printf '# TYPE openwrt_unbound_queries_total gauge\n'
printf '# HELP openwrt_unbound_cache_hits_total Consultas resueltas desde cache\n'
printf '# TYPE openwrt_unbound_cache_hits_total gauge\n'
printf '# HELP openwrt_unbound_cache_miss_total Consultas que requirieron recursion\n'
printf '# TYPE openwrt_unbound_cache_miss_total gauge\n'
printf '# HELP openwrt_unbound_cache_hit_ratio Porcentaje de cache hits (0-1)\n'
printf '# TYPE openwrt_unbound_cache_hit_ratio gauge\n'
printf '# HELP openwrt_unbound_recursion_avg_ms Tiempo promedio de recursion en ms\n'
printf '# TYPE openwrt_unbound_recursion_avg_ms gauge\n'
printf '# HELP openwrt_unbound_recursion_median_ms Tiempo mediano de recursion en ms\n'
printf '# TYPE openwrt_unbound_recursion_median_ms gauge\n'
printf '# HELP openwrt_unbound_prefetch_total Consultas prefetcheadas\n'
printf '# TYPE openwrt_unbound_prefetch_total gauge\n'
printf '# HELP openwrt_unbound_unwanted_queries_total Consultas rechazadas\n'
printf '# TYPE openwrt_unbound_unwanted_queries_total gauge\n'

UB=$(unbound-control stats_noreset 2>/dev/null)
if [ -n "$UB" ]; then
  ub_q=$(echo "$UB"    | awk -F= '/^total\.num\.queries=/{print $2}')
  ub_h=$(echo "$UB"    | awk -F= '/^total\.num\.cachehits=/{print $2}')
  ub_m=$(echo "$UB"    | awk -F= '/^total\.num\.cachemiss=/{print $2}')
  ub_pf=$(echo "$UB"   | awk -F= '/^total\.num\.prefetch=/{print $2}')
  ub_uw=$(echo "$UB"   | awk -F= '/^unwanted\.queries=/{print $2}')
  ub_ra=$(echo "$UB"   | awk -F= '/^total\.recursion\.time\.avg=/{print $2}')
  ub_rm=$(echo "$UB"   | awk -F= '/^total\.recursion\.time\.median=/{print $2}')

  printf 'openwrt_unbound_queries_total %s\n'       "${ub_q:-0}"
  printf 'openwrt_unbound_cache_hits_total %s\n'    "${ub_h:-0}"
  printf 'openwrt_unbound_cache_miss_total %s\n'    "${ub_m:-0}"
  printf 'openwrt_unbound_prefetch_total %s\n'      "${ub_pf:-0}"
  printf 'openwrt_unbound_unwanted_queries_total %s\n' "${ub_uw:-0}"
  # Cache hit ratio
  awk "BEGIN{ q=${ub_q:-0}; h=${ub_h:-0}; printf \"openwrt_unbound_cache_hit_ratio %.4f\n\", (q>0 ? h/q : 0) }"
  # Recursion latency en ms
  awk "BEGIN{ printf \"openwrt_unbound_recursion_avg_ms %.2f\n\",    ${ub_ra:-0}*1000 }"
  awk "BEGIN{ printf \"openwrt_unbound_recursion_median_ms %.2f\n\", ${ub_rm:-0}*1000 }"
fi

# ============================================================
# Conntrack — conexiones activas
# ============================================================
printf '# HELP openwrt_conntrack_count Conexiones activas en conntrack\n'
printf '# TYPE openwrt_conntrack_count gauge\n'
ct=$(cat /proc/net/nf_conntrack_count 2>/dev/null || wc -l < /proc/net/nf_conntrack 2>/dev/null || echo 0)
printf 'openwrt_conntrack_count %s\n' "$ct"

# ============================================================
# Tailscale — peers activos
# ============================================================
printf '# HELP openwrt_tailscale_peers_online Peers Tailscale activos\n'
printf '# TYPE openwrt_tailscale_peers_online gauge\n'
printf 'openwrt_tailscale_peers_online %s\n' "$(tailscale status 2>/dev/null | grep -c 'active')"

# ============================================================
# Overlay filesystem
# ============================================================
printf '# HELP openwrt_overlay_used_bytes Bytes usados en /overlay\n'
printf '# TYPE openwrt_overlay_used_bytes gauge\n'
printf '# HELP openwrt_overlay_avail_bytes Bytes disponibles en /overlay\n'
printf '# TYPE openwrt_overlay_avail_bytes gauge\n'
df /overlay 2>/dev/null | awk 'NR==2{
  printf "openwrt_overlay_used_bytes %s\n", $3*1024
  printf "openwrt_overlay_avail_bytes %s\n", $4*1024
}'

# ============================================================
# Sistema — uptime y DHCP leases
# ============================================================
printf '# HELP openwrt_uptime_seconds Tiempo encendido del router en segundos\n'
printf '# TYPE openwrt_uptime_seconds counter\n'
printf 'openwrt_uptime_seconds %s\n' "$(awk '{print int($1)}' /proc/uptime)"

printf '# HELP openwrt_dhcp_leases_total Clientes DHCP activos\n'
printf '# TYPE openwrt_dhcp_leases_total gauge\n'
printf 'openwrt_dhcp_leases_total %s\n' "$(wc -l < /tmp/dhcp.leases 2>/dev/null || echo 0)"

# ============================================================
# CrowdSec — decisiones activas
# ============================================================
printf '# HELP openwrt_crowdsec_decisions_total IPs bloqueadas actualmente por CrowdSec\n'
printf '# TYPE openwrt_crowdsec_decisions_total gauge\n'
cs_dec=$(cscli decisions list -o json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d) if isinstance(d,list) else 0)" 2>/dev/null || echo 0)
printf 'openwrt_crowdsec_decisions_total %s\n' "${cs_dec:-0}"

# ============================================================
# Servicios críticos — estado (1=running, 0=stopped)
# ============================================================
printf '# HELP openwrt_service_up Estado del servicio (1=activo 0=caido)\n'
printf '# TYPE openwrt_service_up gauge\n'

svc_check() {
  local name="$1" proc="$2"
  if pidof "$proc" > /dev/null 2>&1; then
    printf 'openwrt_service_up{service="%s"} 1\n' "$name"
  else
    printf 'openwrt_service_up{service="%s"} 0\n' "$name"
  fi
}

svc_check "adguardhome"  "AdGuardHome"
svc_check "tailscale"    "tailscaled"
svc_check "dnsmasq"      "dnsmasq"
svc_check "unbound"      "unbound"
svc_check "crowdsec"     "crowdsec"
svc_check "cs-bouncer"   "cs-firewall-bouncer"
svc_check "collectd"     "collectd"
svc_check "irqbalance"   "irqbalance"
svc_check "mdns-repeater" "mdns-repeater"

# mwan3 — al menos una WAN online
if mwan3 status 2>/dev/null | grep -q "is online"; then
  printf 'openwrt_service_up{service="mwan3"} 1\n'
else
  printf 'openwrt_service_up{service="mwan3"} 0\n'
fi

# banip — tabla nft presente
if nft list tables 2>/dev/null | grep -q "banIP"; then
  printf 'openwrt_service_up{service="banip"} 1\n'
else
  printf 'openwrt_service_up{service="banip"} 0\n'
fi

} > "${OUTFILE}.tmp" && mv "${OUTFILE}.tmp" "$OUTFILE"
