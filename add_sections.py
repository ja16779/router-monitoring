import requests, json

GRAFANA_URL = "https://ja16779.grafana.net"
TOKEN = "REDACTED_GRAFANA_TOKEN"
DS = "grafanacloud-prom"
H = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

# Obtener dashboard actual
resp = requests.get(f"{GRAFANA_URL}/api/dashboards/uid/flint2-home", headers=H)
d = resp.json()
dash = d["dashboard"]
version = d["meta"]["version"] if "version" in d.get("meta", {}) else dash.get("version", 1)

def tgt(expr, leg=""):
    return {"datasource": {"uid": DS}, "expr": expr, "legendFormat": leg, "refId": "A"}

def targets(*pairs):
    return [{"datasource": {"uid": DS}, "expr": e, "legendFormat": l, "refId": chr(65+i)}
            for i, (e, l) in enumerate(pairs)]

def row(rid, title, y):
    return {"type": "row", "title": title, "id": rid,
            "gridPos": {"x": 0, "y": y, "w": 24, "h": 1}, "collapsed": False}

def stat(pid, title, expr, x, y, w=4, h=3, unit="", steps=None, decs=1):
    return {
        "id": pid, "title": title, "type": "stat",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": {"uid": DS},
        "targets": [tgt(expr)],
        "options": {"reduceOptions": {"calcs": ["lastNotNull"]}, "colorMode": "background",
                    "textMode": "auto", "graphMode": "area"},
        "fieldConfig": {"defaults": {"unit": unit, "decimals": decs,
            "thresholds": {"mode": "absolute",
                           "steps": steps or [{"color": "green", "value": None}]}}}
    }

def ts(pid, title, tgts, x, y, w, h, unit=""):
    return {
        "id": pid, "title": title, "type": "timeseries",
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "datasource": {"uid": DS},
        "targets": tgts,
        "fieldConfig": {"defaults": {"unit": unit,
            "custom": {"lineWidth": 2, "fillOpacity": 10, "gradientMode": "opacity"}}},
        "options": {"tooltip": {"mode": "multi", "sort": "desc"},
                    "legend": {"displayMode": "table", "placement": "bottom",
                               "calcs": ["last", "max", "min"]}}
    }

# Paneles encontrar el mayor y (para anexar al final)
max_y = max(p["gridPos"]["y"] + p["gridPos"]["h"] for p in dash["panels"])
next_y = max_y + 1
pid = 200  # IDs altos para no colisionar

OK_FAIL = [{"color": "red", "value": None}, {"color": "green", "value": 1}]

new_panels = [

    # ══════════════════════════════════════════════════════════════════
    # mwan3 — Estado y caídas detallado
    # ══════════════════════════════════════════════════════════════════
    row(pid, "🔴 mwan3 — Estado WAN y Caídas", next_y),

    stat(pid+1, "AXTEL uptime actual",
         'openwrt_mwan3_uptime_seconds{interface="wan"}',
         0, next_y+1, 4, 3, "s",
         [{"color": "red", "value": None}, {"color": "orange", "value": 300},
          {"color": "green", "value": 3600}]),
    stat(pid+2, "Megacable uptime actual",
         'openwrt_mwan3_uptime_seconds{interface="secondwan"}',
         4, next_y+1, 4, 3, "s",
         [{"color": "red", "value": None}, {"color": "orange", "value": 300},
          {"color": "green", "value": 3600}]),
    stat(pid+3, "Caídas AXTEL (desde boot)",
         'openwrt_mwan3_failovers_total{interface="wan"}',
         8, next_y+1, 4, 3, decs=0,
         steps=[{"color": "green", "value": None}, {"color": "yellow", "value": 1},
                {"color": "red", "value": 3}]),
    stat(pid+4, "Caídas Megacable (desde boot)",
         'openwrt_mwan3_failovers_total{interface="secondwan"}',
         12, next_y+1, 4, 3, decs=0,
         steps=[{"color": "green", "value": None}, {"color": "yellow", "value": 1},
                {"color": "red", "value": 3}]),
    stat(pid+5, "Duración última caída AXTEL",
         'openwrt_mwan3_last_down_duration_seconds{interface="wan"}',
         16, next_y+1, 4, 3, "s"),
    stat(pid+6, "Duración última caída Megacable",
         'openwrt_mwan3_last_down_duration_seconds{interface="secondwan"}',
         20, next_y+1, 4, 3, "s"),

    # State Timeline — muestra visualmente cuándo estuvo caída cada WAN
    {
        "id": pid+7, "title": "Estado WAN — Histórico (1=online 0=offline)",
        "type": "state-timeline",
        "gridPos": {"x": 0, "y": next_y+4, "w": 24, "h": 6},
        "datasource": {"uid": DS},
        "targets": [
            {"datasource": {"uid": DS},
             "expr": 'openwrt_mwan3_online{interface="wan"}',
             "legendFormat": "AXTEL (Telmex)", "refId": "A"},
            {"datasource": {"uid": DS},
             "expr": 'openwrt_mwan3_online{interface="secondwan"}',
             "legendFormat": "Megacable", "refId": "B"},
        ],
        "options": {"mergeValues": True, "showValue": "never", "alignValue": "left",
                    "rowHeight": 0.9,
                    "legend": {"displayMode": "list", "placement": "bottom"}},
        "fieldConfig": {"defaults": {
            "custom": {"lineWidth": 0, "fillOpacity": 70},
            "mappings": [
                {"type": "value", "options": {"0": {"text": "OFFLINE", "color": "red"},
                                               "1": {"text": "ONLINE",  "color": "green"}}},
            ],
            "thresholds": {"mode": "absolute", "steps": [
                {"color": "red", "value": None},
                {"color": "green", "value": 1}
            ]}
        }}
    },

    ts(pid+8, "Uptime WAN (segundos contínuos online)", targets(
        ('openwrt_mwan3_uptime_seconds{interface="wan"}',       "AXTEL"),
        ('openwrt_mwan3_uptime_seconds{interface="secondwan"}', "Megacable"),
    ), 0, next_y+10, 12, 8, "s"),

    ts(pid+9, "Latencia WAN durante caídas (ping ms)", targets(
        ('openwrt_wan_ping_ms{interface="wan"}',       "AXTEL — ping 8.8.8.8"),
        ('openwrt_wan_ping_ms{interface="secondwan"}', "Megacable — ping 8.8.8.8"),
    ), 12, next_y+10, 12, 8, "ms"),

    # ══════════════════════════════════════════════════════════════════
    # Unbound — DNS recursivo
    # ══════════════════════════════════════════════════════════════════
    row(pid+20, "🔍 Unbound — DNS Recursivo", next_y+18),

    stat(pid+21, "Consultas Unbound",
         'openwrt_unbound_queries_total', 0, next_y+19, 3, 3, decs=0),
    stat(pid+22, "Cache Hits",
         'openwrt_unbound_cache_hits_total', 3, next_y+19, 3, 3, decs=0),
    stat(pid+23, "Cache Ratio",
         'openwrt_unbound_cache_hit_ratio * 100', 6, next_y+19, 3, 3, "percent",
         [{"color": "red", "value": None}, {"color": "yellow", "value": 30},
          {"color": "green", "value": 60}]),
    stat(pid+24, "Recursión avg",
         'openwrt_unbound_recursion_avg_ms', 9, next_y+19, 3, 3, "ms",
         [{"color": "green", "value": None}, {"color": "yellow", "value": 200},
          {"color": "red", "value": 500}]),
    stat(pid+25, "Recursión mediana",
         'openwrt_unbound_recursion_median_ms', 12, next_y+19, 3, 3, "ms",
         [{"color": "green", "value": None}, {"color": "yellow", "value": 150},
          {"color": "red", "value": 400}]),
    stat(pid+26, "Prefetch",
         'openwrt_unbound_prefetch_total', 15, next_y+19, 3, 3, decs=0),
    stat(pid+27, "Queries no deseadas",
         'openwrt_unbound_unwanted_queries_total', 18, next_y+19, 3, 3, decs=0,
         steps=[{"color": "green", "value": None}, {"color": "yellow", "value": 1},
                {"color": "red", "value": 10}]),

    ts(pid+28, "Cache Hits vs Miss (histórico)", targets(
        ('openwrt_unbound_cache_hits_total', "Cache Hits"),
        ('openwrt_unbound_cache_miss_total', "Cache Miss"),
        ('openwrt_unbound_prefetch_total',   "Prefetch"),
    ), 0, next_y+22, 12, 8),

    ts(pid+29, "Latencia de recursión DNS (histórico)", targets(
        ('openwrt_unbound_recursion_avg_ms',    "Promedio"),
        ('openwrt_unbound_recursion_median_ms', "Mediana"),
    ), 12, next_y+22, 12, 8, "ms"),

    ts(pid+30, "Cache Hit Ratio % (histórico)", targets(
        ('openwrt_unbound_cache_hit_ratio * 100', "Hit Ratio %"),
    ), 0, next_y+30, 12, 7, "percent"),

    ts(pid+31, "Unbound vs AdGuardHome — Consultas totales", targets(
        ('openwrt_unbound_queries_total',   "Unbound (recursivo)"),
        ('openwrt_adguard_queries_total',   "AdGuardHome (total)"),
        ('openwrt_adguard_blocked_total',   "AGH bloqueadas"),
    ), 12, next_y+30, 12, 7),
]

dash["panels"].extend(new_panels)

# Guardar
resp = requests.post(
    f"{GRAFANA_URL}/api/dashboards/db",
    headers=H,
    json={"dashboard": dash, "overwrite": True, "folderId": 0,
          "message": "Agrega secciones mwan3 y Unbound"}
)
r = resp.json()
print("Status:", resp.status_code)
print("URL:", GRAFANA_URL + r.get("url", ""))
if resp.status_code != 200:
    print("Error:", json.dumps(r, indent=2)[:500])
