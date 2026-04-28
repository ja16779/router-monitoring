import requests, json

GRAFANA_URL = "https://ja16779.grafana.net"
TOKEN = "REDACTED_GRAFANA_TOKEN"
DS = "grafanacloud-prom"
H = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

resp = requests.get(f"{GRAFANA_URL}/api/dashboards/uid/flint2-home", headers=H)
dash = resp.json()["dashboard"]

# Remover panel 500 anterior
dash["panels"] = [p for p in dash["panels"] if p.get("id") != 500]
max_y = max(p["gridPos"]["y"] + p["gridPos"]["h"] for p in dash["panels"])

# Tabla con 4 queries separadas — cada una instant + format table
# Grafana merge las une por labels comunes automáticamente
table_panel = {
    "id": 500,
    "title": "📋 Clientes WiFi activos — Hostname / IP / Señal / Velocidad",
    "type": "table",
    "gridPos": {"x": 0, "y": max_y + 1, "w": 24, "h": 14},
    "datasource": {"uid": DS},
    "targets": [
        {
            "datasource": {"uid": DS},
            "expr": "openwrt_wifi_station_signal_dbm",
            "instant": True,
            "range": False,
            "format": "table",
            "legendFormat": "",
            "refId": "A",
        },
        {
            "datasource": {"uid": DS},
            "expr": "openwrt_wifi_station_tx_bitrate_mbps",
            "instant": True,
            "range": False,
            "format": "table",
            "legendFormat": "",
            "refId": "B",
        },
        {
            "datasource": {"uid": DS},
            "expr": "openwrt_wifi_station_rx_bitrate_mbps",
            "instant": True,
            "range": False,
            "format": "table",
            "legendFormat": "",
            "refId": "C",
        },
        {
            "datasource": {"uid": DS},
            "expr": "openwrt_wifi_station_inactive_ms / 1000",
            "instant": True,
            "range": False,
            "format": "table",
            "legendFormat": "",
            "refId": "D",
        },
    ],
    "transformations": [
        {"id": "merge", "options": {}},
        {
            "id": "organize",
            "options": {
                "excludeByName": {
                    "Time":      True,
                    "__name__":  True,
                    "job":       True,
                    "instance":  True,
                    "ssid":      True,
                    "location":  True,
                },
                "renameByName": {
                    "hostname":  "Hostname",
                    "ip":        "IP",
                    "mac":       "MAC",
                    "interface": "Radio",
                    "Value #A":  "Señal (dBm)",
                    "Value #B":  "TX (Mbps)",
                    "Value #C":  "RX (Mbps)",
                    "Value #D":  "Inactivo (s)",
                },
                "indexByName": {
                    "hostname":  0,
                    "ip":        1,
                    "mac":       2,
                    "interface": 3,
                    "Value #A":  4,
                    "Value #B":  5,
                    "Value #C":  6,
                    "Value #D":  7,
                }
            }
        },
    ],
    "options": {
        "showHeader": True,
        "footer": {"show": False},
        "sortBy": [{"displayName": "Señal (dBm)", "desc": False}],
    },
    "fieldConfig": {
        "defaults": {
            "custom": {"align": "left", "inspect": False},
        },
        "overrides": [
            {
                "matcher": {"id": "byName", "options": "Señal (dBm)"},
                "properties": [
                    {"id": "unit", "value": "dBm"},
                    {"id": "decimals", "value": 0},
                    {"id": "custom.width", "value": 120},
                    {"id": "custom.displayMode", "value": "color-background"},
                    {"id": "color", "value": {"mode": "thresholds"}},
                    {"id": "thresholds", "value": {
                        "mode": "absolute",
                        "steps": [
                            {"color": "dark-red", "value": None},
                            {"color": "orange",   "value": -85},
                            {"color": "yellow",   "value": -75},
                            {"color": "green",    "value": -65},
                        ]
                    }},
                ]
            },
            {
                "matcher": {"id": "byName", "options": "TX (Mbps)"},
                "properties": [
                    {"id": "unit", "value": "Mbps"},
                    {"id": "decimals", "value": 1},
                    {"id": "custom.width", "value": 100},
                ]
            },
            {
                "matcher": {"id": "byName", "options": "RX (Mbps)"},
                "properties": [
                    {"id": "unit", "value": "Mbps"},
                    {"id": "decimals", "value": 1},
                    {"id": "custom.width", "value": 100},
                ]
            },
            {
                "matcher": {"id": "byName", "options": "Inactivo (s)"},
                "properties": [
                    {"id": "unit", "value": "s"},
                    {"id": "decimals", "value": 1},
                    {"id": "custom.width", "value": 105},
                ]
            },
            {
                "matcher": {"id": "byName", "options": "Hostname"},
                "properties": [{"id": "custom.width", "value": 190}]
            },
            {
                "matcher": {"id": "byName", "options": "IP"},
                "properties": [{"id": "custom.width", "value": 130}]
            },
            {
                "matcher": {"id": "byName", "options": "MAC"},
                "properties": [{"id": "custom.width", "value": 155}]
            },
            {
                "matcher": {"id": "byName", "options": "Radio"},
                "properties": [{"id": "custom.width", "value": 110}]
            },
        ]
    }
}

dash["panels"].append(table_panel)

resp = requests.post(
    f"{GRAFANA_URL}/api/dashboards/db",
    headers=H,
    json={"dashboard": dash, "overwrite": True, "folderId": 0}
)
r = resp.json()
print("Status:", resp.status_code)
print("URL:", GRAFANA_URL + r.get("url", ""))
if resp.status_code != 200:
    print("Error:", json.dumps(r, indent=2)[:800])
