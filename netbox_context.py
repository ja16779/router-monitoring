#!/usr/bin/env python3
"""
netbox_context.py — Crea Config Context y Config Template para los routers en NetBox
"""

import sys
try:
    import requests
except ImportError:
    sys.exit("pip install requests")

NETBOX_URL   = "http://localhost:8000"
BEARER_TOKEN = "nbt_zt7eOYaY6E0F.168wDYUx9SNF5zj9IQc24qbUSm6djRNiUYU8tlfy"

HEADERS = {
    "Authorization": f"Bearer {BEARER_TOKEN}",
    "Accept":        "application/json",
    "Content-Type":  "application/json",
}

# ─── Config Contexts (datos estructurados por dispositivo) ───────────────────

CONTEXTS = [
    {
        "name": "flint2-config",
        "weight": 1000,
        "description": "Configuracion Flint 2 (GL-MT6000)",
        "data": {
            "hostname": "GL-MT6000",
            "platform": "OpenWrt 24.10.4",
            "hardware": {
                "model":  "GL-MT6000",
                "vendor": "GL.iNet",
                "arch":   "aarch64",
                "mac_lan": "94:83:c4:a6:3b:d9",
                "mac_wan": "94:83:c4:a6:3b:d8"
            },
            "wan": {
                "interface":  "wan",
                "device":     "eth1.881",
                "proto":      "pppoe",
                "vlan_id":    881,
                "mtu":        1492,
                "local_ip":   "187.138.212.71",
                "peer_ip":    "200.38.193.226",
                "public_ip":  "177.245.36.55",
                "cgnat":      True,
                "username":   "44F436LZTEG245294E1@prodigyweb.com.mx",
                "multipath":  "on",
                "keepalive":  "10 6"
            },
            "interfaces": {
                "IOT": {
                    "device":   "br-lan.8",
                    "vlan_id":  8,
                    "proto":    "static",
                    "ipaddr":   "192.168.8.1",
                    "netmask":  "255.255.255.0",
                    "subnet":   "192.168.8.0/24",
                    "dns":      "127.0.0.1",
                    "ports":    ["lan5:t"]
                },
                "lan": {
                    "device":   "br-lan.10",
                    "vlan_id":  10,
                    "proto":    "static",
                    "ipaddr":   "192.168.10.1",
                    "netmask":  "255.255.255.0",
                    "subnet":   "192.168.10.0/24",
                    "dns":      "127.0.0.1",
                    "ports":    ["lan2", "lan3", "lan4", "lan5:t"]
                },
                "guest": {
                    "device":   "br-guest",
                    "proto":    "static",
                    "ipaddr":   "192.168.9.1",
                    "netmask":  "255.255.255.0",
                    "subnet":   "192.168.9.0/24"
                }
            },
            "bridge": {
                "name":   "br-lan",
                "type":   "bridge",
                "ports":  ["lan2", "lan3", "lan4", "lan5"],
                "stp":    False
            },
            "wireless": {
                "radio0": {
                    "band":    "2.4 GHz",
                    "channel": 6,
                    "htmode":  "HE20",
                    "country": "MX",
                    "txpower": 20
                },
                "radio1": {
                    "band":    "5 GHz",
                    "channel": 44,
                    "htmode":  "HE80",
                    "country": "MX"
                },
                "ssids": [
                    {"ssid": "AXTEL XTREMO", "radio": "radio0", "band": "2.4G", "encryption": "psk-mixed", "network": "lan"},
                    {"ssid": "AXTEL XTREMO", "radio": "radio1", "band": "5G",   "encryption": "psk2",     "network": "lan"},
                    {"ssid": "IOT",          "radio": "radio0", "band": "2.4G", "encryption": "psk-mixed", "network": "IOT"},
                    {"ssid": "Mega_2.4G_A2DF","radio": "radio0","band": "2.4G", "encryption": "psk-mixed", "network": "guest"},
                    {"ssid": "Mega_5G_A2DF", "radio": "radio1", "band": "5G",   "encryption": "psk2",     "network": "guest"}
                ]
            },
            "firewall": {
                "zones": [
                    {"name": "lan",   "input": "ACCEPT", "output": "ACCEPT", "forward": "ACCEPT", "networks": ["lan"]},
                    {"name": "iot",   "input": "ACCEPT", "output": "ACCEPT", "forward": "DROP",   "networks": ["IOT"]},
                    {"name": "guest", "input": "ACCEPT", "output": "ACCEPT", "forward": "ACCEPT", "networks": ["guest"], "masq": True},
                    {"name": "wan",   "input": "DROP",   "output": "ACCEPT", "forward": "DROP",   "networks": ["wan", "wan6"], "masq": True, "mtu_fix": True}
                ],
                "forwardings": [
                    {"src": "lan",   "dest": "wan"},
                    {"src": "iot",   "dest": "wan"},
                    {"src": "guest", "dest": "wan"},
                    {"src": "lan",   "dest": "iot"}
                ]
            },
            "mwan3": {
                "interfaces": [
                    {"name": "wan", "enabled": True, "track_ip": ["8.8.8.8", "8.8.4.4"], "reliability": 1}
                ],
                "members": [
                    {"name": "wan_m1_w3", "interface": "wan", "metric": 1, "weight": 3}
                ],
                "policies": [
                    {"name": "wan_only", "use_member": "wan_m1_w3"}
                ]
            },
            "services": {
                "adguardhome": True,
                "mdns_repeater": {
                    "enabled":    True,
                    "interfaces": ["br-lan.8", "br-lan.10"]
                },
                "ddns": {
                    "service": "gl_ddns",
                    "status":  "disabled",
                    "reason":  "BusyBox host returns exit 127 for NXDOMAIN causing infinite retry loop"
                }
            }
        }
    }
]

# ─── Config Template (Jinja2) ────────────────────────────────────────────────

TEMPLATE_OPENWRT = """\
# ============================================================
# Generado por NetBox Config Template
# Device: {{ device.name }} | Platform: {{ device.platform }}
# ============================================================

# /etc/config/network

config interface 'loopback'
    option device 'lo'
    option proto 'static'
    option ipaddr '127.0.0.1'
    option netmask '255.0.0.0'

# Bridge LAN
config device
    option name '{{ config_context.bridge.name }}'
    option type '{{ config_context.bridge.type }}'
{% for port in config_context.bridge.ports %}    list ports '{{ port }}'
{% endfor %}    option stp '{{ '1' if config_context.bridge.stp else '0' }}'

# Interfaces VLAN
{% for iface_name, iface in config_context.interfaces.items() %}
config interface '{{ iface_name }}'
    option device '{{ iface.device }}'
    option proto '{{ iface.proto }}'
    option ipaddr '{{ iface.ipaddr }}'
    option netmask '{{ iface.netmask }}'
{% if iface.dns is defined %}    option dns '{{ iface.dns }}'
{% endif %}
{% endfor %}

# WAN
config interface 'wan'
    option device '{{ config_context.wan.device }}'
    option proto '{{ config_context.wan.proto }}'
    option mtu '{{ config_context.wan.mtu }}'

# ============================================================
# /etc/config/firewall
# ============================================================
{% for zone in config_context.firewall.zones %}
config zone
    option name '{{ zone.name }}'
    option input '{{ zone.input }}'
    option output '{{ zone.output }}'
    option forward '{{ zone.forward }}'
{% if zone.masq is defined and zone.masq %}    option masq '1'
{% endif %}
{% for net in zone.networks %}    list network '{{ net }}'
{% endfor %}
{% endfor %}

{% for fwd in config_context.firewall.forwardings %}
config forwarding
    option src '{{ fwd.src }}'
    option dest '{{ fwd.dest }}'
{% endfor %}

# ============================================================
# /etc/config/wireless
# ============================================================

config wifi-device 'radio0'
    option band '2g'
    option channel '{{ config_context.wireless.radio0.channel }}'
    option htmode '{{ config_context.wireless.radio0.htmode }}'
    option country '{{ config_context.wireless.radio0.country }}'

config wifi-device 'radio1'
    option band '5g'
    option channel '{{ config_context.wireless.radio1.channel }}'
    option htmode '{{ config_context.wireless.radio1.htmode }}'
    option country '{{ config_context.wireless.radio1.country }}'

{% for ssid in config_context.wireless.ssids %}
config wifi-iface
    option device '{{ ssid.radio }}'
    option mode 'ap'
    option ssid '{{ ssid.ssid }}'
    option encryption '{{ ssid.encryption }}'
    option network '{{ ssid.network }}'
{% endfor %}
"""


# ─── API helpers ─────────────────────────────────────────────────────────────

def api_get(path, params=None):
    results, url = [], f"{NETBOX_URL}{path}"
    while url:
        r = requests.get(url, headers=HEADERS, params=params, timeout=10)
        r.raise_for_status()
        d = r.json()
        if "results" in d:
            results.extend(d["results"])
            url, params = d.get("next"), {}
        else:
            return d
    return results


def api_post(path, data):
    r = requests.post(f"{NETBOX_URL}{path}", headers=HEADERS, json=data, timeout=10)
    if not r.ok:
        print(f"  [!] POST {path} {r.status_code}: {r.text[:300]}")
        return {}
    return r.json()


def api_patch(path, data):
    r = requests.patch(f"{NETBOX_URL}{path}", headers=HEADERS, json=data, timeout=10)
    if not r.ok:
        print(f"  [!] PATCH {path} {r.status_code}: {r.text[:300]}")
        return {}
    return r.json()


def get_or_create(path, lookup, create_data, label):
    existing = api_get(path, params=lookup)
    if existing:
        obj = existing[0]
        print(f"  [OK]  {label} ya existe (id={obj['id']})")
        return obj
    obj = api_post(path, create_data)
    if obj.get("id"):
        print(f"  [+]   {label} creado (id={obj['id']})")
    return obj


# ─── Crear Config Contexts ────────────────────────────────────────────────────

def setup_contexts():
    print("\n── Config Contexts ──")
    for ctx in CONTEXTS:
        existing = api_get("/api/extras/config-contexts/", params={"name": ctx["name"]})
        if existing:
            obj = existing[0]
            # Actualizar data
            r = api_patch(f"/api/extras/config-contexts/{obj['id']}/", {
                "data":        ctx["data"],
                "description": ctx["description"],
                "weight":      ctx["weight"],
            })
            print(f"  [~]   '{ctx['name']}' actualizado (id={obj['id']})")
        else:
            obj = api_post("/api/extras/config-contexts/", ctx)
            print(f"  [+]   '{ctx['name']}' creado (id={obj.get('id')})")

        # Asignar al device Flint 2
        assign_context_to_device(obj.get("id"), "Flint 2")


def assign_context_to_device(context_id, device_name):
    devices = api_get("/api/dcim/devices/", params={"name": device_name})
    if not devices:
        print(f"  [!] Device '{device_name}' no encontrado")
        return
    device = devices[0]
    # En NetBox los Config Contexts se asignan automáticamente por device/role/platform
    # Solo confirmamos que el device existe
    print(f"  [★]   Context disponible para '{device_name}' (device id={device['id']})")


# ─── Crear Config Template ────────────────────────────────────────────────────

def setup_template():
    print("\n── Config Template ──")

    # Buscar platform OpenWrt
    platforms = api_get("/api/dcim/platforms/", params={"slug": "openwrt"})
    platform_id = platforms[0]["id"] if platforms else None

    template_data = {
        "name":        "OpenWrt UCI Config",
        "description": "Genera configuracion UCI para routers OpenWrt (network, firewall, wireless)",
        "template_code": TEMPLATE_OPENWRT,
    }

    existing = api_get("/api/extras/config-templates/", params={"name": "OpenWrt UCI Config"})
    if existing:
        obj = api_patch(f"/api/extras/config-templates/{existing[0]['id']}/", template_data)
        print(f"  [~]   Template actualizado (id={existing[0]['id']})")
        tmpl_id = existing[0]["id"]
    else:
        obj = api_post("/api/extras/config-templates/", template_data)
        tmpl_id = obj.get("id")
        print(f"  [+]   Template creado (id={tmpl_id})")

    # Asignar template al device Flint 2
    if tmpl_id:
        devices = api_get("/api/dcim/devices/", params={"name": "Flint 2"})
        if devices:
            api_patch(f"/api/dcim/devices/{devices[0]['id']}/", {"config_template": tmpl_id})
            print(f"  [★]   Template asignado a 'Flint 2'")


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    print(f"NetBox: {NETBOX_URL}")
    try:
        requests.get(f"{NETBOX_URL}/api/", headers=HEADERS, timeout=5).raise_for_status()
    except Exception:
        sys.exit("No se puede conectar a NetBox.")

    setup_contexts()
    setup_template()

    print(f"\n{'═'*55}")
    print("  Listo. En NetBox:")
    print(f"  Config Context: {NETBOX_URL}/extras/config-contexts/")
    print(f"  Config Template: {NETBOX_URL}/dcim/config-templates/")
    print(f"  Render Config: {NETBOX_URL}/dcim/devices/ → Flint 2 → Render Config")


if __name__ == "__main__":
    main()
