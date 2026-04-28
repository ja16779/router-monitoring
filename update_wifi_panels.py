import requests, json

GRAFANA_URL = "https://ja16779.grafana.net"
TOKEN = "REDACTED_GRAFANA_TOKEN"
DS = "grafanacloud-prom"
H = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

resp = requests.get(f"{GRAFANA_URL}/api/dashboards/uid/flint2-home", headers=H)
d = resp.json()
dash = d["dashboard"]

def tgt(expr, leg, ref="A"):
    return {"datasource": {"uid": DS}, "expr": expr, "legendFormat": leg, "refId": ref}

# Actualizar paneles WiFi que usan {{mac}} → {{hostname}} ({{ip}})
for p in dash["panels"]:
    for t in p.get("targets", []):
        leg = t.get("legendFormat", "")
        # Actualizar leyendas que tenían solo mac
        if "{{mac}}" in leg and "{{hostname}}" not in leg:
            t["legendFormat"] = leg.replace("{{mac}}", "{{hostname}} ({{ip}})")

# Reemplazar los paneles WiFi específicos con versiones mejoradas
panels_to_update = {
    37: {  # Señal WiFi por cliente
        "title": "Señal WiFi por cliente (dBm)",
        "targets": [tgt("openwrt_wifi_station_signal_dbm",
                        "{{hostname}} ({{ip}}) @ {{interface}}")],
        "options": {
            "tooltip": {"mode": "multi", "sort": "asc"},
            "legend": {"displayMode": "table", "placement": "right",
                       "calcs": ["last", "min"]}
        }
    },
    38: {  # Bargauge señal actual
        "title": "Señal actual por cliente — dBm (mejor = menos negativo)",
        "targets": [tgt("openwrt_wifi_station_signal_dbm",
                        "{{hostname}} ({{ip}})")]
    },
    39: {  # TX Bitrate
        "title": "TX Bitrate por cliente (Mbps)",
        "targets": [tgt("openwrt_wifi_station_tx_bitrate_mbps",
                        "TX {{hostname}} ({{ip}}) @ {{interface}}")]
    },
    40: {  # Tráfico por cliente
        "title": "Tráfico por cliente WiFi",
        "targets": [
            tgt('rate(openwrt_wifi_station_rx_bytes_total[5m])*8',
                "↓ {{hostname}} ({{ip}})", "A"),
            tgt('rate(openwrt_wifi_station_tx_bytes_total[5m])*8',
                "↑ {{hostname}} ({{ip}})", "B"),
        ]
    },
}

for p in dash["panels"]:
    pid = p.get("id")
    if pid in panels_to_update:
        upd = panels_to_update[pid]
        if "title" in upd:
            p["title"] = upd["title"]
        if "targets" in upd:
            p["targets"] = upd["targets"]
        if "options" in upd:
            p["options"].update(upd["options"])

# Agregar tabla de clientes WiFi activos con hostname + IP + señal + bitrate
# Buscar el max Y del dashboard
max_y = max(p["gridPos"]["y"] + p["gridPos"]["h"] for p in dash["panels"])

table_panel = {
    "id": 500,
    "title": "📋 Clientes WiFi activos — Hostname / IP / Señal / Velocidad",
    "type": "table",
    "gridPos": {"x": 0, "y": max_y + 1, "w": 24, "h": 12},
    "datasource": {"uid": DS},
    "targets": [
        {
            "datasource": {"uid": DS},
            "expr": "openwrt_wifi_station_signal_dbm",
            "legendFormat": "",
            "refId": "A",
            "instant": True,
            "format": "table"
        },
        {
            "datasource": {"uid": DS},
            "expr": "openwrt_wifi_station_tx_bitrate_mbps",
            "legendFormat": "",
            "refId": "B",
            "instant": True,
            "format": "table"
        },
        {
            "datasource": {"uid": DS},
            "expr": "openwrt_wifi_station_rx_bitrate_mbps",
            "legendFormat": "",
            "refId": "C",
            "instant": True,
            "format": "table"
        },
        {
            "datasource": {"uid": DS},
            "expr": "openwrt_wifi_station_inactive_ms / 1000",
            "legendFormat": "",
            "refId": "D",
            "instant": True,
            "format": "table"
        },
    ],
    "options": {
        "sortBy": [{"displayName": "Señal (dBm)", "desc": False}],
        "footer": {"show": False},
        "showHeader": True,
    },
    "fieldConfig": {
        "defaults": {"custom": {"align": "auto"}},
        "overrides": [
            {
                "matcher": {"id": "byName", "options": "hostname"},
                "properties": [{"id": "displayName", "value": "Hostname"},
                               {"id": "custom.width", "value": 180}]
            },
            {
                "matcher": {"id": "byName", "options": "ip"},
                "properties": [{"id": "displayName", "value": "IP"},
                               {"id": "custom.width", "value": 130}]
            },
            {
                "matcher": {"id": "byName", "options": "mac"},
                "properties": [{"id": "displayName", "value": "MAC"},
                               {"id": "custom.width", "value": 150}]
            },
            {
                "matcher": {"id": "byName", "options": "interface"},
                "properties": [{"id": "displayName", "value": "SSID/Radio"},
                               {"id": "custom.width", "value": 120}]
            },
            {
                "matcher": {"id": "byName", "options": "Value #A"},
                "properties": [
                    {"id": "displayName", "value": "Señal (dBm)"},
                    {"id": "unit", "value": "dBm"},
                    {"id": "custom.width", "value": 110},
                    {"id": "thresholds", "value": {
                        "mode": "absolute",
                        "steps": [{"color": "red", "value": None},
                                  {"color": "orange", "value": -85},
                                  {"color": "yellow", "value": -75},
                                  {"color": "green", "value": -65}]
                    }},
                    {"id": "custom.displayMode", "value": "color-background"},
                ]
            },
            {
                "matcher": {"id": "byName", "options": "Value #B"},
                "properties": [{"id": "displayName", "value": "TX (Mbps)"},
                               {"id": "unit", "value": "Mbps"},
                               {"id": "custom.width", "value": 100}]
            },
            {
                "matcher": {"id": "byName", "options": "Value #C"},
                "properties": [{"id": "displayName", "value": "RX (Mbps)"},
                               {"id": "unit", "value": "Mbps"},
                               {"id": "custom.width", "value": 100}]
            },
            {
                "matcher": {"id": "byName", "options": "Value #D"},
                "properties": [{"id": "displayName", "value": "Inactivo (s)"},
                               {"id": "unit", "value": "s"},
                               {"id": "custom.width", "value": 110}]
            },
            # Ocultar columnas que no necesitamos
            *[{"matcher": {"id": "byName", "options": col},
               "properties": [{"id": "custom.hidden", "value": True}]}
              for col in ["Time", "__name__", "job", "instance", "ssid"]]
        ]
    },
    "transformations": [
        {"id": "merge", "options": {}},
        {"id": "organize", "options": {
            "excludeByName": {"Time": True, "__name__": True,
                              "job": True, "instance": True, "ssid": True},
            "indexByName": {
                "hostname": 0, "ip": 1, "mac": 2,
                "interface": 3, "Value #A": 4,
                "Value #B": 5, "Value #C": 6, "Value #D": 7
            }
        }}
    ]
}

dash["panels"].append(table_panel)

resp = requests.post(
    f"{GRAFANA_URL}/api/dashboards/db",
    headers=H,
    json={"dashboard": dash, "overwrite": True, "folderId": 0,
          "message": "WiFi clients: agrega hostname e IP en labels y tabla"}
)
r = resp.json()
print("Status:", resp.status_code)
print("URL:", GRAFANA_URL + r.get("url", ""))
if resp.status_code != 200:
    print("Error:", json.dumps(r, indent=2)[:500])
