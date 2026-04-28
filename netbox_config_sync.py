#!/usr/bin/env python3
"""
netbox_config_sync.py — Obtiene la config de los routers via SSH y la guarda en NetBox
Crea custom fields: running_config, firmware_version, last_config_sync
Uso: python netbox_config_sync.py
"""

import sys
from datetime import datetime, timezone

try:
    import paramiko
    import requests
except ImportError as e:
    sys.exit(f"Instala dependencias: pip install paramiko requests\nFaltante: {e}")

NETBOX_URL   = "http://localhost:8000"
BEARER_TOKEN = "nbt_zt7eOYaY6E0F.168wDYUx9SNF5zj9IQc24qbUSm6djRNiUYU8tlfy"

HEADERS = {
    "Authorization": f"Bearer {BEARER_TOKEN}",
    "Accept":        "application/json",
    "Content-Type":  "application/json",
}

# ─── Dispositivos con acceso SSH ─────────────────────────────────────────────

DEVICES = [
    {
        "netbox_name": "Flint 2",
        "host":        "192.168.8.1",
        "port":        22,
        "username":    "root",
        "password":    "admin",
        "hostkey":     "ssh-ed25519 255 SHA256:L9OLGWFWcoo2rMfv27q3C5nri7n3YFwqz9l5fAUfaA4",
    },
    # {
    #     "netbox_name": "Beryl AX",
    #     "host":        "192.168.X.X",   # <-- agrega la IP del Beryl cuando la tengas
    #     "port":        22,
    #     "username":    "root",
    #     "password":    "admin",
    # },
]

# Comandos a ejecutar en el router
COMMANDS = {
    "running_config":   "uci export 2>/dev/null",
    "firmware_version": "grep DISTRIB_RELEASE /etc/openwrt_release | cut -d'=' -f2 | tr -d \"'\"",
}


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
        print(f"  [!] POST {path} {r.status_code}: {r.text[:200]}")
        return {}
    return r.json()


def api_patch(path, data):
    r = requests.patch(f"{NETBOX_URL}{path}", headers=HEADERS, json=data, timeout=10)
    if not r.ok:
        print(f"  [!] PATCH {path} {r.status_code}: {r.text[:200]}")
        return {}
    return r.json()


# ─── Custom Fields ────────────────────────────────────────────────────────────

CUSTOM_FIELDS = [
    {
        "name":         "running_config",
        "label":        "Running Config",
        "type":         "longtext",
        "object_types": ["dcim.device"],
        "group_name":   "Configuration",
        "description":  "Configuracion UCI exportada del router",
        "ui_visible":   "always",
        "ui_editable":  "yes",
    },
    {
        "name":         "firmware_version",
        "label":        "Firmware Version",
        "type":         "text",
        "object_types": ["dcim.device"],
        "group_name":   "Configuration",
        "description":  "Version de OpenWrt/firmware",
        "ui_visible":   "always",
        "ui_editable":  "yes",
    },
    {
        "name":         "last_config_sync",
        "label":        "Last Config Sync",
        "type":         "text",
        "object_types": ["dcim.device"],
        "group_name":   "Configuration",
        "description":  "Fecha/hora del ultimo sync de configuracion",
        "ui_visible":   "always",
        "ui_editable":  "hidden",
    },
]


def ensure_custom_fields():
    print("\n── Custom Fields ──")
    existing = {cf["name"] for cf in api_get("/api/extras/custom-fields/")}
    for cf in CUSTOM_FIELDS:
        if cf["name"] in existing:
            print(f"  [OK]  '{cf['name']}' ya existe")
        else:
            res = api_post("/api/extras/custom-fields/", cf)
            if res.get("id"):
                print(f"  [+]   '{cf['name']}' creado (id={res['id']})")
            else:
                print(f"  [!]   No se pudo crear '{cf['name']}'")


# ─── SSH ──────────────────────────────────────────────────────────────────────

def ssh_run(device_cfg: dict, command: str) -> str:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(
            hostname=device_cfg["host"],
            port=device_cfg.get("port", 22),
            username=device_cfg["username"],
            password=device_cfg["password"],
            timeout=15,
            look_for_keys=False,
            allow_agent=False,
        )
        _, stdout, stderr = client.exec_command(command, timeout=30)
        output = stdout.read().decode("utf-8", errors="replace").strip()
        client.close()
        return output
    except Exception as e:
        return f"ERROR: {e}"


def fetch_device_config(device_cfg: dict) -> dict:
    print(f"\n── SSH → {device_cfg['host']} ({device_cfg['netbox_name']}) ──")
    results = {}
    for field, cmd in COMMANDS.items():
        print(f"  Ejecutando: {cmd[:50]}…")
        output = ssh_run(device_cfg, cmd)
        if output.startswith("ERROR:"):
            print(f"  [!] {output}")
            results[field] = None
        else:
            lines = output.count("\n") + 1
            print(f"  [OK] {lines} líneas obtenidas")
            results[field] = output
    return results


# ─── Actualizar dispositivo en NetBox ─────────────────────────────────────────

def update_device(netbox_name: str, config_data: dict):
    devices = api_get("/api/dcim/devices/", params={"name": netbox_name})
    if not devices:
        print(f"  [!] Device '{netbox_name}' no encontrado en NetBox")
        return

    device = devices[0]
    device_id = device["id"]

    custom_fields = {}
    if config_data.get("running_config"):
        custom_fields["running_config"] = config_data["running_config"]
    if config_data.get("firmware_version"):
        custom_fields["firmware_version"] = config_data["firmware_version"]
    custom_fields["last_config_sync"] = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    result = api_patch(f"/api/dcim/devices/{device_id}/", {"custom_fields": custom_fields})
    if result.get("id"):
        print(f"  [★]   NetBox actualizado — Device id={device_id}")
        if config_data.get("firmware_version"):
            print(f"        Firmware: {config_data['firmware_version']}")
    else:
        print(f"  [!]   Error actualizando device {device_id}")


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    print(f"NetBox: {NETBOX_URL}")
    try:
        requests.get(f"{NETBOX_URL}/api/", headers=HEADERS, timeout=5).raise_for_status()
    except Exception:
        sys.exit("No se puede conectar a NetBox.")

    # 1. Crear custom fields si no existen
    ensure_custom_fields()

    # 2. Para cada router: SSH → obtener config → guardar en NetBox
    for dev in DEVICES:
        config_data = fetch_device_config(dev)
        update_device(dev["netbox_name"], config_data)

    print(f"\n{'═'*55}")
    print(f"  Listo. Revisa en NetBox → Devices → [device] → Custom Fields")
    print(f"  {NETBOX_URL}/dcim/devices/")


if __name__ == "__main__":
    main()
