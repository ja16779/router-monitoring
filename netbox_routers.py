#!/usr/bin/env python3
"""
netbox_routers.py — Registra los routers GL.iNet en NetBox (DCIM)
Crea: Manufacturer, Device Types, Site, Device Role, Devices, Interfaces, IPs
"""

import sys

try:
    import requests
except ImportError:
    sys.exit("Instala requests: pip install requests")

NETBOX_URL   = "http://localhost:8000"
BEARER_TOKEN = "nbt_zt7eOYaY6E0F.168wDYUx9SNF5zj9IQc24qbUSm6djRNiUYU8tlfy"

HEADERS = {
    "Authorization": f"Bearer {BEARER_TOKEN}",
    "Accept":        "application/json",
    "Content-Type":  "application/json",
}

# ─── Definición de los routers ───────────────────────────────────────────────

SITE_NAME = "Home"

ROUTERS = [
    {
        "name":        "Flint 2",
        "device_type": "GL-MT6000",
        "role":        "Router",
        "platform":    "OpenWrt 24.10",
        "serial":      "",
        "comments":    "Router principal. OpenWrt 24.10 (GL.iNet). PPPoE WAN.",
        "interfaces": [
            {
                "name":  "pppoe-wan",
                "type":  "virtual",
                "descr": "WAN PPPoE",
                "ips":   ["187.138.212.71/32"],
            },
            {
                "name":  "eth0",
                "type":  "1000base-t",
                "descr": "WAN physical port",
                "ips":   [],
            },
            {
                "name":  "br-lan",
                "type":  "virtual",
                "descr": "LAN bridge",
                "ips":   ["192.168.8.1/24"],
                "primary": True,
            },
            {
                "name":  "br-lan.8",
                "type":  "virtual",
                "descr": "VLAN 8 - IoT",
                "ips":   [],
            },
            {
                "name":  "br-lan.10",
                "type":  "virtual",
                "descr": "VLAN 10 - LAN Principal",
                "ips":   [],
            },
        ],
    },
    {
        "name":        "Beryl AX",
        "device_type": "GL-MT3000",
        "role":        "Router",
        "platform":    "OpenWrt 24.10",
        "serial":      "",
        "comments":    "Router secundario / AP. OpenWrt 24.10 (GL.iNet). Conectado a Flint 2.",
        "interfaces": [
            {
                "name":  "eth1",
                "type":  "1000base-t",
                "descr": "WAN uplink → Flint 2",
                "ips":   [],
            },
            {
                "name":  "br-lan",
                "type":  "virtual",
                "descr": "LAN bridge",
                "ips":   [],
                "primary": True,
            },
            {
                "name":  "br-lan.8",
                "type":  "virtual",
                "descr": "VLAN 8 - IoT",
                "ips":   [],
            },
            {
                "name":  "br-lan.10",
                "type":  "virtual",
                "descr": "VLAN 10 - LAN Principal",
                "ips":   [],
            },
        ],
    },
]

MANUFACTURER = {
    "name": "GL.iNet",
    "slug": "glinet",
}

DEVICE_TYPES = [
    {
        "model":        "GL-MT6000",
        "slug":         "gl-mt6000",
        "part_number":  "GL-MT6000",
        "u_height":     1,
        "comments":     "Flint 2 — WiFi 6, aarch64, OpenWrt",
    },
    {
        "model":        "GL-MT3000",
        "slug":         "gl-mt3000",
        "part_number":  "GL-MT3000",
        "u_height":     1,
        "comments":     "Beryl AX — WiFi 6, aarch64, OpenWrt",
    },
]


# ─── API helpers ─────────────────────────────────────────────────────────────

def api_get(path: str, params: dict = None):
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


def api_post(path: str, data: dict) -> dict:
    r = requests.post(f"{NETBOX_URL}{path}", headers=HEADERS, json=data, timeout=10)
    if not r.ok:
        print(f"  [!] POST {path} error {r.status_code}: {r.text[:200]}")
        return {}
    return r.json()


def api_patch(path: str, data: dict) -> dict:
    r = requests.patch(f"{NETBOX_URL}{path}", headers=HEADERS, json=data, timeout=10)
    if not r.ok:
        print(f"  [!] PATCH {path} error {r.status_code}: {r.text[:200]}")
        return {}
    return r.json()


def get_or_create(path: str, lookup: dict, create_data: dict, label: str) -> dict:
    """Busca un objeto por lookup; si no existe, lo crea."""
    existing = api_get(path, params=lookup)
    if existing:
        obj = existing[0]
        print(f"  [OK]  {label} '{obj.get('name') or obj.get('model')}' ya existe (id={obj['id']})")
        return obj
    obj = api_post(path, create_data)
    print(f"  [+]   {label} '{obj.get('name') or obj.get('model')}' creado (id={obj.get('id')})")
    return obj


# ─── Crear infraestructura base ───────────────────────────────────────────────

def setup_manufacturer() -> dict:
    print("\n── Manufacturer ──")
    return get_or_create(
        "/api/dcim/manufacturers/",
        {"slug": MANUFACTURER["slug"]},
        MANUFACTURER,
        "Manufacturer",
    )


def setup_device_types(manufacturer_id: int) -> dict:
    print("\n── Device Types ──")
    types = {}
    for dt in DEVICE_TYPES:
        obj = get_or_create(
            "/api/dcim/device-types/",
            {"slug": dt["slug"]},
            {**dt, "manufacturer": manufacturer_id},
            "DeviceType",
        )
        types[dt["model"]] = obj["id"]
    return types


def setup_site() -> dict:
    print("\n── Site ──")
    slug = SITE_NAME.lower().replace(" ", "-")
    return get_or_create(
        "/api/dcim/sites/",
        {"slug": slug},
        {"name": SITE_NAME, "slug": slug, "status": "active"},
        "Site",
    )


def setup_role() -> dict:
    print("\n── Device Role ──")
    return get_or_create(
        "/api/dcim/device-roles/",
        {"slug": "router"},
        {"name": "Router", "slug": "router", "color": "2196f3", "vm_role": False},
        "DeviceRole",
    )


def setup_platform() -> dict:
    print("\n── Platform ──")
    return get_or_create(
        "/api/dcim/platforms/",
        {"slug": "openwrt"},
        {"name": "OpenWrt", "slug": "openwrt"},
        "Platform",
    )


# ─── Interfaces e IPs ─────────────────────────────────────────────────────────

def get_or_create_interface(device_id: int, iface: dict) -> dict:
    existing = api_get("/api/dcim/interfaces/", params={"device_id": device_id, "name": iface["name"]})
    if existing:
        obj = existing[0]
        print(f"      [OK]  iface {iface['name']} ya existe")
        return obj
    obj = api_post("/api/dcim/interfaces/", {
        "device":       device_id,
        "name":         iface["name"],
        "type":         iface["type"],
        "description":  iface.get("descr", ""),
        "enabled":      True,
    })
    print(f"      [+]   iface {iface['name']} creada")
    return obj


def assign_ip(address: str, interface_id: int, device_id: int, make_primary: bool = False) -> dict:
    existing = api_get("/api/ipam/ip-addresses/", params={"address": address})
    if existing:
        ip_obj = existing[0]
        # Update assigned_object if not set
        if not ip_obj.get("assigned_object_id"):
            api_patch(f"/api/ipam/ip-addresses/{ip_obj['id']}/", {
                "assigned_object_type": "dcim.interface",
                "assigned_object_id":   interface_id,
                "status": "active",
            })
            print(f"      [~]   IP {address} asignada a interface")
        else:
            print(f"      [OK]  IP {address} ya asignada")
    else:
        ip_obj = api_post("/api/ipam/ip-addresses/", {
            "address":              address,
            "status":               "active",
            "assigned_object_type": "dcim.interface",
            "assigned_object_id":   interface_id,
        })
        print(f"      [+]   IP {address} creada y asignada")

    if make_primary and ip_obj.get("id"):
        # Detectar si es v4 o v6
        family = "primary_ip4" if "." in address else "primary_ip6"
        api_patch(f"/api/dcim/devices/{device_id}/", {family: ip_obj["id"]})
        print(f"      [★]   IP {address} marcada como primary")

    return ip_obj


# ─── Crear dispositivos ───────────────────────────────────────────────────────

def create_router(router: dict, device_type_id: int, site_id: int, role_id: int, platform_id: int):
    print(f"\n── Device: {router['name']} ──")

    existing = api_get("/api/dcim/devices/", params={"name": router["name"]})
    if existing:
        device = existing[0]
        print(f"  [OK]  Device '{router['name']}' ya existe (id={device['id']})")
    else:
        device = api_post("/api/dcim/devices/", {
            "name":        router["name"],
            "device_type": device_type_id,
            "role":        role_id,
            "site":        site_id,
            "platform":    platform_id,
            "status":      "active",
            "comments":    router.get("comments", ""),
        })
        if not device.get("id"):
            print(f"  [!] No se pudo crear {router['name']}")
            return
        print(f"  [+]   Device '{router['name']}' creado (id={device['id']})")

    device_id = device["id"]

    # Crear interfaces y asignar IPs
    for iface_cfg in router["interfaces"]:
        iface_obj = get_or_create_interface(device_id, iface_cfg)
        if not iface_obj.get("id"):
            continue
        for ip_addr in iface_cfg.get("ips", []):
            assign_ip(ip_addr, iface_obj["id"], device_id, make_primary=iface_cfg.get("primary", False))


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    print(f"NetBox: {NETBOX_URL}")
    try:
        r = requests.get(f"{NETBOX_URL}/api/", headers=HEADERS, timeout=5)
        r.raise_for_status()
    except Exception:
        sys.exit("No se puede conectar a NetBox.")

    # Infraestructura base
    mfr      = setup_manufacturer()
    dt_map   = setup_device_types(mfr["id"])
    site     = setup_site()
    role     = setup_role()
    platform = setup_platform()

    # Crear routers
    for router in ROUTERS:
        dt_id = dt_map.get(router["device_type"])
        if not dt_id:
            print(f"[!] DeviceType '{router['device_type']}' no encontrado, saltando {router['name']}")
            continue
        create_router(router, dt_id, site["id"], role["id"], platform["id"])

    print(f"\n{'═'*55}")
    print("  Listo. Revisa en NetBox → Devices")
    print(f"  {NETBOX_URL}/dcim/devices/")


if __name__ == "__main__":
    main()
