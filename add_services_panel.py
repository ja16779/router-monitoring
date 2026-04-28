import requests, json

GRAFANA_URL = "https://ja16779.grafana.net"
TOKEN = "REDACTED_GRAFANA_TOKEN"
DS = "grafanacloud-prom"
H = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

resp = requests.get(f"{GRAFANA_URL}/api/dashboards/uid/flint2-home", headers=H)
dash = resp.json()["dashboard"]

# Eliminar panel anterior si existe
dash["panels"] = [p for p in dash["panels"] if p.get("id") != 600]

max_y = max(p["gridPos"]["y"] + p["gridPos"]["h"] for p in dash["panels"])

# Orden visual deseado (críticos primero)
SERVICES = [
    "mwan3",
    "adguardhome",
    "unbound",
    "dnsmasq",
    "crowdsec",
    "cs-bouncer",
    "banip",
    "tailscale",
    "collectd",
    "irqbalance",
    "mdns-repeater",
]

services_panel = {
    "id": 600,
    "title": "🔧 Estado Servicios Críticos",
    "type": "stat",
    "gridPos": {"x": 0, "y": max_y + 1, "w": 24, "h": 4},
    "datasource": {"uid": DS},
    "targets": [
        {
            "datasource": {"uid": DS},
            "expr": 'openwrt_service_up',
            "instant": True,
            "range": False,
            "legendFormat": "{{service}}",
            "refId": "A",
        }
    ],
    "options": {
        "reduceOptions": {
            "calcs": ["lastNotNull"],
            "fields": "",
            "values": False,
        },
        "orientation": "horizontal",
        "textMode": "name",
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "center",
        "text": {"titleSize": 13, "valueSize": 0},
    },
    "fieldConfig": {
        "defaults": {
            "mappings": [
                {
                    "type": "value",
                    "options": {
                        "0": {"text": "CAÍDO",   "color": "dark-red",   "index": 0},
                        "1": {"text": "OK",      "color": "dark-green", "index": 1},
                    },
                }
            ],
            "thresholds": {
                "mode": "absolute",
                "steps": [
                    {"color": "dark-red",   "value": None},
                    {"color": "dark-green", "value": 1},
                ],
            },
            "color": {"mode": "thresholds"},
            "noValue": "N/D",
        },
        "overrides": [],
    },
    "transformations": [
        {
            "id": "sortBy",
            "options": {
                "fields": [{"displayName": "Value", "desc": False}]
            }
        }
    ],
}

dash["panels"].append(services_panel)

resp = requests.post(
    f"{GRAFANA_URL}/api/dashboards/db",
    headers=H,
    json={"dashboard": dash, "overwrite": True, "folderId": 0,
          "message": "Agrega panel de estado de servicios críticos"}
)
r = resp.json()
print("Status:", resp.status_code)
print("URL:", GRAFANA_URL + r.get("url", ""))
if resp.status_code != 200:
    print("Error:", json.dumps(r, indent=2)[:500])
