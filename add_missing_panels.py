import requests, json

GRAFANA_URL = "https://ja16779.grafana.net"
TOKEN = "REDACTED_GRAFANA_TOKEN"
DS = "grafanacloud-prom"
H = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

resp = requests.get(f"{GRAFANA_URL}/api/dashboards/uid/flint2-home", headers=H)
dash = resp.json()["dashboard"]

# Limpiar paneles anteriores si existen
NUEVOS_IDS = list(range(700, 730))
dash["panels"] = [p for p in dash["panels"] if p.get("id") not in NUEVOS_IDS]

max_y = max(p["gridPos"]["y"] + p["gridPos"]["h"] for p in dash["panels"])
Y = max_y + 1

# ── helpers ─────────────────────────────────────────────────────────────
def row(pid, title, y):
    return {"id": pid, "type": "row", "title": title,
            "gridPos": {"x": 0, "y": y, "w": 24, "h": 1}, "collapsed": False}

def stat(pid, title, expr, x, y, w=4, h=3, unit="", decimals=1, steps=None, instant=False):
    return {
        "id": pid, "title": title, "type": "stat",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": {"uid": DS},
        "targets": [{"datasource": {"uid": DS}, "expr": expr,
                     "instant": instant, "legendFormat": "", "refId": "A"}],
        "options": {"reduceOptions": {"calcs": ["lastNotNull"]},
                    "colorMode": "background", "graphMode": "area", "textMode": "auto"},
        "fieldConfig": {"defaults": {"unit": unit, "decimals": decimals,
            "thresholds": {"mode": "absolute",
                           "steps": steps or [{"color": "green", "value": None}]}}},
    }

def ts(pid, title, targets, x, y, w, h, unit=""):
    return {
        "id": pid, "title": title, "type": "timeseries",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": {"uid": DS},
        "targets": targets,
        "fieldConfig": {"defaults": {"unit": unit,
            "custom": {"lineWidth": 2, "fillOpacity": 10, "gradientMode": "opacity"}}},
        "options": {"tooltip": {"mode": "multi", "sort": "desc"},
                    "legend": {"displayMode": "table", "placement": "bottom",
                               "calcs": ["last", "max"]}},
    }

def tgt(expr, leg, ref="A"):
    return {"datasource": {"uid": DS}, "expr": expr,
            "legendFormat": leg, "refId": ref}

def tgt_i(expr, ref="A"):
    return {"datasource": {"uid": DS}, "expr": expr,
            "instant": True, "range": False, "format": "table",
            "legendFormat": "", "refId": ref}

# ─────────────────────────────────────────────────────────────────────────
# 1. Estadísticas de sistema — Uptime y DHCP (insertar en overview)
#    Añadimos 2 stats al final de overview (y=1, después de los existentes)
# ─────────────────────────────────────────────────────────────────────────
overview_stats = [
    stat(700, "Uptime router", "openwrt_uptime_seconds",
         x=0, y=1, w=4, h=3, unit="s", decimals=0,
         steps=[{"color": "red", "value": None},
                {"color": "orange", "value": 300},
                {"color": "green", "value": 3600}]),
    stat(701, "Clientes DHCP", "openwrt_dhcp_leases_total",
         x=4, y=1, w=4, h=3, unit="", decimals=0,
         steps=[{"color": "green", "value": None}]),
]
# Desplazar stats de overview que ocupan x=0..3 y x=4..7 → ya ocupados
# En realidad el overview tiene 12 stats en x=0,2,4,6,8,10,12,14,16,18,20,22
# con w=2 cada uno. Agregamos fila nueva en y=4 (antes del panel de servicios)
# Mejor ponerlos al final del dashboard en sección dedicada

# ─────────────────────────────────────────────────────────────────────────
# Secciones nuevas al final del dashboard
# ─────────────────────────────────────────────────────────────────────────
new_panels = []

# ══ WiFi — Top tráfico y clientes inactivos ══════════════════════════════
new_panels.append(row(702, "📶 WiFi — Tráfico y Actividad", Y))

new_panels.append({
    "id": 703,
    "title": "🏆 Top clientes por tráfico (Mbps)",
    "type": "table",
    "gridPos": {"x": 0, "y": Y+1, "w": 12, "h": 10},
    "datasource": {"uid": DS},
    "targets": [
        {**tgt_i("topk(15, (rate(openwrt_wifi_station_rx_bytes_total[5m]) + rate(openwrt_wifi_station_tx_bytes_total[5m])) * 8 / 1e6)", "A")},
    ],
    "transformations": [
        {"id": "merge", "options": {}},
        {"id": "organize", "options": {
            "excludeByName": {"Time": True, "__name__": True, "job": True,
                              "instance": True, "location": True, "ssid": True},
            "renameByName": {"hostname": "Hostname", "ip": "IP",
                             "interface": "Radio", "Value": "Tráfico (Mbps)"},
            "indexByName": {"hostname": 0, "ip": 1, "interface": 2, "Value": 3},
        }},
        {"id": "sortBy", "options": {"fields": [{"displayName": "Tráfico (Mbps)", "desc": True}]}},
    ],
    "options": {"showHeader": True, "footer": {"show": False}, "cellHeight": "sm"},
    "fieldConfig": {
        "defaults": {"custom": {"align": "left"}},
        "overrides": [
            {"matcher": {"id": "byName", "options": "Hostname"},
             "properties": [{"id": "custom.width", "value": 180}]},
            {"matcher": {"id": "byName", "options": "IP"},
             "properties": [{"id": "custom.width", "value": 120}]},
            {"matcher": {"id": "byName", "options": "Radio"},
             "properties": [{"id": "custom.width", "value": 100}]},
            {"matcher": {"id": "byName", "options": "Tráfico (Mbps)"},
             "properties": [
                 {"id": "unit", "value": "Mbps"},
                 {"id": "decimals", "value": 2},
                 {"id": "custom.width", "value": 130},
                 {"id": "custom.displayMode", "value": "lcd-gauge"},
             ]},
        ],
    },
})

new_panels.append({
    "id": 704,
    "title": "💤 Clientes inactivos >5 min",
    "type": "table",
    "gridPos": {"x": 12, "y": Y+1, "w": 12, "h": 10},
    "datasource": {"uid": DS},
    "targets": [
        {**tgt_i("openwrt_wifi_station_inactive_ms > 300000", "A")},
    ],
    "transformations": [
        {"id": "merge", "options": {}},
        {"id": "organize", "options": {
            "excludeByName": {"Time": True, "__name__": True, "job": True,
                              "instance": True, "location": True, "ssid": True},
            "renameByName": {"hostname": "Hostname", "ip": "IP",
                             "mac": "MAC", "interface": "Radio",
                             "Value": "Inactivo (s)"},
            "indexByName": {"hostname": 0, "ip": 1, "mac": 2,
                            "interface": 3, "Value": 4},
        }},
        {"id": "calculateField", "options": {
            "alias": "Inactivo (s)",
            "mode": "reduceRow",
            "reduce": {"reducer": "sum"},
        }},
        {"id": "sortBy", "options": {"fields": [{"displayName": "Inactivo (s)", "desc": True}]}},
    ],
    "options": {"showHeader": True, "footer": {"show": False}, "cellHeight": "sm"},
    "fieldConfig": {
        "defaults": {"custom": {"align": "left"}},
        "overrides": [
            {"matcher": {"id": "byName", "options": "Hostname"},
             "properties": [{"id": "custom.width", "value": 180}]},
            {"matcher": {"id": "byName", "options": "IP"},
             "properties": [{"id": "custom.width", "value": 120}]},
            {"matcher": {"id": "byName", "options": "MAC"},
             "properties": [{"id": "custom.width", "value": 150}]},
            {"matcher": {"id": "byName", "options": "Radio"},
             "properties": [{"id": "custom.width", "value": 100}]},
            {"matcher": {"id": "byName", "options": "Value"},
             "properties": [
                 {"id": "unit", "value": "s"},
                 {"id": "decimals", "value": 0},
                 {"id": "custom.width", "value": 120},
                 {"id": "custom.displayMode", "value": "color-background"},
                 {"id": "thresholds", "value": {"mode": "absolute", "steps": [
                     {"color": "yellow", "value": None},
                     {"color": "orange", "value": 900},
                     {"color": "red",    "value": 3600},
                 ]}},
             ]},
        ],
    },
})

new_panels.append(ts(705, "📈 Tráfico total WiFi por cliente (histórico)",
    [tgt('rate(openwrt_wifi_station_rx_bytes_total[5m])*8/1e6',
         "↓ {{hostname}} ({{ip}})"),
     tgt('rate(openwrt_wifi_station_tx_bytes_total[5m])*8/1e6',
         "↑ {{hostname}} ({{ip}})")],
    0, Y+11, 24, 8, "Mbps"))

# ══ Sistema — Uptime, DHCP, CrowdSec ═════════════════════════════════════
new_panels.append(row(710, "⚙️ Sistema — Uptime / DHCP / Seguridad", Y+19))

new_panels.append(stat(711, "⏱ Uptime router",
    "openwrt_uptime_seconds",
    x=0, y=Y+20, w=4, h=4, unit="s", decimals=0,
    steps=[{"color": "red",    "value": None},
           {"color": "orange", "value": 3600},
           {"color": "green",  "value": 86400}]))

new_panels.append(stat(712, "👥 Clientes DHCP activos",
    "openwrt_dhcp_leases_total",
    x=4, y=Y+20, w=4, h=4, unit="", decimals=0,
    steps=[{"color": "green", "value": None},
           {"color": "yellow", "value": 40},
           {"color": "red",    "value": 50}]))

new_panels.append(stat(713, "🛡 CrowdSec — IPs bloqueadas",
    "openwrt_crowdsec_decisions_total",
    x=8, y=Y+20, w=4, h=4, unit="", decimals=0,
    steps=[{"color": "green", "value": None}]))

new_panels.append(stat(714, "🔒 Conntrack actual",
    "openwrt_conntrack_count",
    x=12, y=Y+20, w=4, h=4, unit="", decimals=0,
    steps=[{"color": "green",  "value": None},
           {"color": "yellow", "value": 8000},
           {"color": "red",    "value": 15000}]))

new_panels.append(stat(715, "💾 Overlay usado",
    "openwrt_overlay_used_bytes / (openwrt_overlay_used_bytes + openwrt_overlay_avail_bytes) * 100",
    x=16, y=Y+20, w=4, h=4, unit="percent", decimals=1,
    steps=[{"color": "green",  "value": None},
           {"color": "yellow", "value": 70},
           {"color": "red",    "value": 85}]))

new_panels.append(ts(716, "📊 Uptime del router (histórico)",
    [tgt("openwrt_uptime_seconds / 3600", "Uptime (horas)")],
    0, Y+24, 12, 7, "h"))

new_panels.append(ts(717, "👥 Clientes DHCP (histórico)",
    [tgt("openwrt_dhcp_leases_total", "Leases activos")],
    12, Y+24, 12, 7, ""))

new_panels.append(ts(718, "🛡 CrowdSec decisions + Conntrack (histórico)",
    [tgt("openwrt_crowdsec_decisions_total", "IPs bloqueadas CrowdSec"),
     tgt("openwrt_conntrack_count / 10",     "Conntrack ÷10")],
    0, Y+31, 24, 8, ""))

# Agregar al dashboard
for p in new_panels:
    dash["panels"].append(p)

resp = requests.post(
    f"{GRAFANA_URL}/api/dashboards/db",
    headers=H,
    json={"dashboard": dash, "overwrite": True, "folderId": 0,
          "message": "Agrega paneles: WiFi top tráfico, inactivos, uptime, DHCP, CrowdSec"}
)
r = resp.json()
print("Status:", resp.status_code)
print("URL:", GRAFANA_URL + r.get("url", ""))
if resp.status_code != 200:
    print("Error:", json.dumps(r, indent=2)[:500])
else:
    print(f"Paneles totales: {len(dash['panels'])}")
