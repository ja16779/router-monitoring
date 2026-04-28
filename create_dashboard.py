import requests, json

GRAFANA_URL = "https://ja16779.grafana.net"
TOKEN = "REDACTED_GRAFANA_TOKEN"
DS = "grafanacloud-prom"
H = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

def target(expr, leg="", ref="A"):
    return {"datasource": {"uid": DS}, "expr": expr, "legendFormat": leg, "refId": ref}

def targets(*pairs):
    return [target(e, l, chr(65+i)) for i, (e, l) in enumerate(pairs)]

def row(rid, title, y, collapsed=False):
    return {"type": "row", "title": title, "id": rid,
            "gridPos": {"x": 0, "y": y, "w": 24, "h": 1}, "collapsed": collapsed}

def stat(pid, title, expr, x, y, w=4, h=3, unit="", steps=None, decs=1):
    return {
        "id": pid, "title": title, "type": "stat",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": {"uid": DS},
        "targets": [target(expr)],
        "options": {"reduceOptions": {"calcs": ["lastNotNull"]}, "colorMode": "background",
                    "textMode": "auto", "graphMode": "area"},
        "fieldConfig": {"defaults": {
            "unit": unit, "decimals": decs,
            "thresholds": {"mode": "absolute",
                           "steps": steps or [{"color": "green", "value": None}]}
        }}
    }

def ts(pid, title, tgts, x, y, w, h, unit="", fill=0.1, legend_pos="bottom"):
    return {
        "id": pid, "title": title, "type": "timeseries",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": {"uid": DS},
        "targets": tgts,
        "fieldConfig": {"defaults": {"unit": unit,
            "custom": {"lineWidth": 2, "fillOpacity": int(fill*100), "gradientMode": "opacity"}}},
        "options": {"tooltip": {"mode": "multi", "sort": "desc"},
                    "legend": {"displayMode": "table", "placement": legend_pos,
                               "calcs": ["last", "max", "min"]}}
    }

def gauge(pid, title, expr, x, y, w, h, unit="", min_=0, max_=100, steps=None):
    return {
        "id": pid, "title": title, "type": "gauge",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": {"uid": DS},
        "targets": [target(expr)],
        "options": {"reduceOptions": {"calcs": ["lastNotNull"]}, "showThresholdLabels": False},
        "fieldConfig": {"defaults": {
            "unit": unit, "min": min_, "max": max_,
            "thresholds": {"mode": "absolute",
                           "steps": steps or [{"color": "green", "value": None}]}
        }}
    }

def barsm(pid, title, tgts, x, y, w, h, unit=""):
    return {
        "id": pid, "title": title, "type": "bargauge",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": {"uid": DS},
        "targets": tgts,
        "options": {"reduceOptions": {"calcs": ["lastNotNull"]}, "orientation": "horizontal",
                    "displayMode": "gradient"},
        "fieldConfig": {"defaults": {"unit": unit,
            "thresholds": {"mode": "absolute", "steps": [
                {"color": "green", "value": None},
                {"color": "yellow", "value": -75},
                {"color": "red", "value": -85}
            ]}
        }}
    }

# Thresholds shortcuts
OK_FAIL = [{"color": "red", "value": None}, {"color": "green", "value": 1}]
LAT     = [{"color": "green", "value": None}, {"color": "yellow", "value": 50},  {"color": "red", "value": 100}]
TEMP    = [{"color": "green", "value": None}, {"color": "yellow", "value": 60},  {"color": "red", "value": 70}]
CPU     = [{"color": "green", "value": None}, {"color": "yellow", "value": 70},  {"color": "red", "value": 90}]
RAM_S   = [{"color": "red", "value": None},   {"color": "yellow", "value": 104857600}, {"color": "green", "value": 209715200}]
DNS_L   = [{"color": "green", "value": None}, {"color": "yellow", "value": 50},  {"color": "red", "value": 200}]

INST = 'instance="flint-2"'

panels = [

    # ══════════════════════════════════════════════════════════════════
    # OVERVIEW — fila de resumen rápido
    # ══════════════════════════════════════════════════════════════════
    row(1, "📊 Overview", 0),

    stat(2,  "AXTEL",        f'openwrt_mwan3_online{{interface="wan"}}',       0, 1, 2, 3, steps=OK_FAIL, decs=0),
    stat(3,  "Megacable",    f'openwrt_mwan3_online{{interface="secondwan"}}', 2, 1, 2, 3, steps=OK_FAIL, decs=0),
    stat(4,  "Lat AXTEL",    f'openwrt_wan_ping_ms{{interface="wan"}}',        4, 1, 2, 3, "ms", LAT),
    stat(5,  "Lat Mega",     f'openwrt_wan_ping_ms{{interface="secondwan"}}',  6, 1, 2, 3, "ms", LAT),
    stat(6,  "WiFi clientes",'sum(openwrt_wifi_stations)',                     8, 1, 2, 3, decs=0),
    stat(7,  "CPU %",        f'100-avg(rate(node_cpu_seconds_total{{{INST},mode="idle"}}[5m]))*100',
             10, 1, 2, 3, "percent", CPU),
    stat(8,  "RAM libre",    f'node_memory_MemAvailable_bytes{{{INST}}}',     12, 1, 2, 3, "bytes", RAM_S),
    stat(9,  "Temp CPU",     f'node_thermal_zone_temp{{{INST},zone="0"}}',    14, 1, 2, 3, "celsius", TEMP),
    stat(10, "DNS queries",  'openwrt_adguard_queries_total',                 16, 1, 2, 3, decs=0),
    stat(11, "Bloqueadas",   'openwrt_adguard_blocked_total',                 18, 1, 2, 3, decs=0),
    stat(12, "Conntrack",    'openwrt_conntrack_count',                       20, 1, 2, 3, decs=0),
    stat(13, "Overlay",      'openwrt_overlay_avail_bytes',                   22, 1, 2, 3, "bytes"),

    # ══════════════════════════════════════════════════════════════════
    # WAN — Conectividad
    # ══════════════════════════════════════════════════════════════════
    row(20, "🌐 WAN — Conectividad", 4),

    ts(21, "Latencia por WAN (ms)", targets(
        ('openwrt_wan_ping_ms{interface="wan"}',       "AXTEL (Telmex)"),
        ('openwrt_wan_ping_ms{interface="secondwan"}', "Megacable"),
    ), 0, 5, 12, 8, "ms"),

    ts(22, "Tráfico WAN (bps)", targets(
        (f'rate(node_network_receive_bytes_total{{{INST},device="pppoe-wan"}}[5m])*8',  "↓ AXTEL"),
        (f'rate(node_network_transmit_bytes_total{{{INST},device="pppoe-wan"}}[5m])*8', "↑ AXTEL"),
        (f'rate(node_network_receive_bytes_total{{{INST},device="lan1"}}[5m])*8',       "↓ Megacable"),
        (f'rate(node_network_transmit_bytes_total{{{INST},device="lan1"}}[5m])*8',      "↑ Megacable"),
    ), 12, 5, 12, 8, "bps"),

    ts(23, "Tráfico LAN (br-lan)", targets(
        (f'rate(node_network_receive_bytes_total{{{INST},device="br-lan"}}[5m])*8',  "↓ LAN"),
        (f'rate(node_network_transmit_bytes_total{{{INST},device="br-lan"}}[5m])*8', "↑ LAN"),
    ), 0, 13, 8, 7, "bps"),

    ts(24, "Conntrack (conexiones activas)", targets(
        ('openwrt_conntrack_count', "Conexiones"),
    ), 8, 13, 8, 7),

    ts(25, "Tailscale peers activos", targets(
        ('openwrt_tailscale_peers_online', "Peers online"),
    ), 16, 13, 8, 7),

    # ══════════════════════════════════════════════════════════════════
    # WiFi — Clientes y Señal
    # ══════════════════════════════════════════════════════════════════
    row(30, "📶 WiFi — Clientes y Señal", 20),

    stat(31, "IOT 2.4G",    'openwrt_wifi_stations{interface="phy0-ap0"}', 0,  21, 3, 3, decs=0),
    stat(32, "Mega 2.4G",   'openwrt_wifi_stations{interface="phy0-ap1"}', 3,  21, 3, 3, decs=0),
    stat(33, "AXTEL 5G",    'openwrt_wifi_stations{interface="phy1-ap0"}', 6,  21, 3, 3, decs=0),
    stat(34, "Mega 5G",     'openwrt_wifi_stations{interface="phy1-ap1"}', 9,  21, 3, 3, decs=0),
    stat(35, "Total WiFi",  'sum(openwrt_wifi_stations)',                  12, 21, 4, 3, decs=0),

    ts(36, "Clientes WiFi por SSID (histórico)", targets(
        ('openwrt_wifi_stations{interface="phy0-ap0"}', "IOT 2.4G"),
        ('openwrt_wifi_stations{interface="phy0-ap1"}', "Mega 2.4G"),
        ('openwrt_wifi_stations{interface="phy1-ap0"}', "AXTEL 5G"),
        ('openwrt_wifi_stations{interface="phy1-ap1"}', "Mega 5G"),
    ), 0, 24, 12, 8),

    {
        "id": 37, "title": "Señal WiFi por cliente (dBm)", "type": "timeseries",
        "gridPos": {"x": 12, "y": 24, "w": 12, "h": 8},
        "datasource": {"uid": DS},
        "targets": [target("openwrt_wifi_station_signal_dbm", "{{mac}} @ {{interface}}")],
        "fieldConfig": {"defaults": {"unit": "dBm", "custom": {"lineWidth": 1, "fillOpacity": 0},
            "thresholds": {"mode": "absolute", "steps": [
                {"color": "red", "value": None}, {"color": "orange", "value": -85},
                {"color": "yellow", "value": -75}, {"color": "green", "value": -65}
            ]}}},
        "options": {"tooltip": {"mode": "multi", "sort": "asc"},
                    "legend": {"displayMode": "table", "placement": "right", "calcs": ["last"]}}
    },

    barsm(38, "Señal actual por cliente (dBm)", [
        target("openwrt_wifi_station_signal_dbm", "{{mac}} @ {{interface}}")
    ], 0, 32, 12, 7, "dBm"),

    ts(39, "TX Bitrate por cliente (Mbps)", targets(
        ("openwrt_wifi_station_tx_bitrate_mbps", "TX {{mac}} @ {{interface}}"),
    ), 12, 32, 12, 7, "Mbps"),

    ts(40, "Tráfico por cliente WiFi", targets(
        ('rate(openwrt_wifi_station_rx_bytes_total[5m])*8', "↓ {{mac}}"),
        ('rate(openwrt_wifi_station_tx_bytes_total[5m])*8', "↑ {{mac}}"),
    ), 0, 39, 24, 8, "bps"),

    # ══════════════════════════════════════════════════════════════════
    # DNS — AdGuardHome + Unbound
    # ══════════════════════════════════════════════════════════════════
    row(50, "🛡️ DNS — AdGuardHome", 47),

    stat(51, "Consultas 24h",  'openwrt_adguard_queries_total', 0, 48, 4, 3, decs=0),
    stat(52, "Bloqueadas 24h", 'openwrt_adguard_blocked_total', 4, 48, 4, 3, decs=0),
    stat(53, "% Bloqueadas",
         '100*openwrt_adguard_blocked_total/clamp_min(openwrt_adguard_queries_total,1)',
         8, 48, 4, 3, "percent"),
    stat(54, "Latencia DNS",   'openwrt_adguard_avg_processing_ms', 12, 48, 4, 3, "ms", DNS_L),

    ts(55, "Consultas y Bloqueadas DNS (histórico)", targets(
        ("openwrt_adguard_queries_total", "Total consultas"),
        ("openwrt_adguard_blocked_total", "Bloqueadas"),
    ), 0, 51, 12, 8),

    ts(56, "Latencia DNS (histórico)", targets(
        ("openwrt_adguard_avg_processing_ms", "Latencia avg"),
    ), 12, 51, 12, 8, "ms"),

    # ══════════════════════════════════════════════════════════════════
    # SISTEMA — CPU / RAM / Disco / Temperatura
    # ══════════════════════════════════════════════════════════════════
    row(60, "⚙️ Sistema — CPU / RAM / Disco / Temperatura", 59),

    gauge(61, "CPU %",
          f'100-avg(rate(node_cpu_seconds_total{{{INST},mode="idle"}}[5m]))*100',
          0, 60, 4, 6, "percent", 0, 100,
          [{"color": "green", "value": None}, {"color": "yellow", "value": 70}, {"color": "red", "value": 90}]),

    gauge(62, "RAM usada %",
          f'100*(1-node_memory_MemAvailable_bytes{{{INST}}}/node_memory_MemTotal_bytes{{{INST}}})',
          4, 60, 4, 6, "percent", 0, 100,
          [{"color": "green", "value": None}, {"color": "yellow", "value": 70}, {"color": "red", "value": 85}]),

    gauge(63, "Temperatura CPU",
          f'node_thermal_zone_temp{{{INST},zone="0"}}',
          8, 60, 4, 6, "celsius", 30, 85, TEMP),

    ts(64, "CPU por modo (idle/user/system/iowait)", targets(
        (f'avg(rate(node_cpu_seconds_total{{{INST},mode="user"}}[5m]))*100',    "user %"),
        (f'avg(rate(node_cpu_seconds_total{{{INST},mode="system"}}[5m]))*100',  "system %"),
        (f'avg(rate(node_cpu_seconds_total{{{INST},mode="iowait"}}[5m]))*100',  "iowait %"),
        (f'avg(rate(node_cpu_seconds_total{{{INST},mode="softirq"}}[5m]))*100', "softirq %"),
    ), 12, 60, 12, 6, "percent"),

    ts(65, "Load Average (1m / 5m / 15m)", targets(
        (f'node_load1{{{INST}}}',  "1 min"),
        (f'node_load5{{{INST}}}',  "5 min"),
        (f'node_load15{{{INST}}}', "15 min"),
    ), 0, 66, 8, 7),

    ts(66, "Memoria RAM", targets(
        (f'node_memory_MemTotal_bytes{{{INST}}}',     "Total"),
        (f'node_memory_MemAvailable_bytes{{{INST}}}', "Disponible"),
        (f'node_memory_Buffers_bytes{{{INST}}}',      "Buffers"),
        (f'node_memory_Cached_bytes{{{INST}}}',       "Cached"),
    ), 8, 66, 8, 7, "bytes"),

    ts(67, "Temperatura histórico", targets(
        (f'node_thermal_zone_temp{{{INST},zone="0"}}', "CPU °C"),
    ), 16, 66, 8, 7, "celsius"),

    ts(68, "Filesystems — Espacio usado", targets(
        (f'node_filesystem_size_bytes{{{INST},fstype!="tmpfs"}}-node_filesystem_avail_bytes{{{INST},fstype!="tmpfs"}}',
         "Usado {{mountpoint}}"),
    ), 0, 73, 12, 7, "bytes"),

    ts(69, "Overlay y USB — Espacio libre", targets(
        ('openwrt_overlay_avail_bytes', "Overlay libre"),
        (f'node_filesystem_avail_bytes{{{INST},mountpoint="/mnt/usb"}}', "USB libre"),
    ), 12, 73, 12, 7, "bytes"),

    # ══════════════════════════════════════════════════════════════════
    # RED — Interfaces completas
    # ══════════════════════════════════════════════════════════════════
    row(70, "🔌 Red — Todas las interfaces", 80),

    ts(71, "Tráfico por interfaz (RX)", [
        target(
            f'rate(node_network_receive_bytes_total{{{INST},device!~"lo|tailscale.*"}}[5m])*8',
            "↓ {{device}}"
        )
    ], 0, 81, 12, 8, "bps"),

    ts(72, "Tráfico por interfaz (TX)", [
        target(
            f'rate(node_network_transmit_bytes_total{{{INST},device!~"lo|tailscale.*"}}[5m])*8',
            "↑ {{device}}"
        )
    ], 12, 81, 12, 8, "bps"),

    ts(73, "Errores y drops de red", targets(
        (f'rate(node_network_receive_errs_total{{{INST}}}[5m])',      "RX errors {{device}}"),
        (f'rate(node_network_receive_drop_total{{{INST}}}[5m])',      "RX drops {{device}}"),
        (f'rate(node_network_transmit_errs_total{{{INST}}}[5m])',     "TX errors {{device}}"),
        (f'rate(node_network_transmit_drop_total{{{INST}}}[5m])',     "TX drops {{device}}"),
    ), 0, 89, 24, 7),
]

dashboard = {
    "title": "Flint-2 — Red Domestica",
    "uid": "flint2-home",
    "tags": ["openwrt", "flint2", "home", "wifi", "wan"],
    "timezone": "browser",
    "refresh": "1m",
    "time": {"from": "now-6h", "to": "now"},
    "panels": panels,
    "schemaVersion": 36,
}

# Borrar el Node Exporter Full separado (opcional, no crítico)
requests.delete(f"{GRAFANA_URL}/api/dashboards/uid/rYdddlPWk", headers=H)

resp = requests.post(
    f"{GRAFANA_URL}/api/dashboards/db",
    headers=H,
    json={"dashboard": dashboard, "overwrite": True, "folderId": 0}
)
r = resp.json()
print("Status:", resp.status_code)
print("URL:", GRAFANA_URL + r.get("url", ""))
if resp.status_code != 200:
    print("Error:", json.dumps(r, indent=2))
