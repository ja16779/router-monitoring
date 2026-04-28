#!/usr/bin/env python3
"""
netbox_scan.py — Registra prefijos VLAN 8 y VLAN 10 en NetBox y escanea hosts activos
Uso: python netbox_scan.py [--scan] [--register]
"""

import ipaddress
import platform
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

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

# Prefijos a registrar
PREFIXES = [
    {
        "prefix":      "192.168.8.0/24",
        "description": "VLAN 8 - IoT",
        "status":      "active",
        "comments":    "Red IoT - br-lan.8",
    },
    {
        "prefix":      "192.168.10.0/24",
        "description": "VLAN 10 - LAN Principal",
        "status":      "active",
        "comments":    "Red principal - br-lan.10",
    },
]


# ─── API helpers ─────────────────────────────────────────────────────────────

def api_get(path: str, params: dict = None) -> list:
    results, url = [], f"{NETBOX_URL}{path}"
    while url:
        r = requests.get(url, headers=HEADERS, params=params, timeout=10)
        r.raise_for_status()
        d = r.json()
        results.extend(d["results"])
        url, params = d.get("next"), {}
    return results


def api_post(path: str, data: dict) -> dict:
    r = requests.post(f"{NETBOX_URL}{path}", headers=HEADERS, json=data, timeout=10)
    r.raise_for_status()
    return r.json()


def api_patch(path: str, data: dict) -> dict:
    r = requests.patch(f"{NETBOX_URL}{path}", headers=HEADERS, json=data, timeout=10)
    r.raise_for_status()
    return r.json()


# ─── Registrar prefijos ──────────────────────────────────────────────────────

def ensure_prefixes():
    print("\n── Registrando prefijos en NetBox ──")
    existing = {p["prefix"]: p for p in api_get("/api/ipam/prefixes/")}

    for cfg in PREFIXES:
        if cfg["prefix"] in existing:
            print(f"  [OK]  {cfg['prefix']} — ya existe")
        else:
            result = api_post("/api/ipam/prefixes/", cfg)
            print(f"  [+]   {cfg['prefix']} — creado (id={result['id']})")


# ─── Ping scan ───────────────────────────────────────────────────────────────

def ping(ip: str) -> bool:
    if platform.system() == "Windows":
        cmd = ["ping", "-n", "1", "-w", "500", str(ip)]
    else:
        cmd = ["ping", "-c", "1", "-W", "1", str(ip)]
    r = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return r.returncode == 0


def scan_subnet(cidr: str, workers: int = 50) -> list[str]:
    net = ipaddress.ip_network(cidr, strict=False)
    hosts = list(net.hosts())
    active = []

    print(f"\n── Escaneando {cidr} ({len(hosts)} hosts, {workers} hilos) ──")
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futures = {ex.submit(ping, str(ip)): str(ip) for ip in hosts}
        done = 0
        for f in as_completed(futures):
            done += 1
            ip = futures[f]
            if f.result():
                active.append(ip)
                print(f"  [UP]  {ip}")
            # Progreso cada 10%
            if done % max(1, len(hosts) // 10) == 0:
                pct = done * 100 // len(hosts)
                print(f"  … {pct}% ({done}/{len(hosts)})", end="\r")

    print(f"  Activos encontrados: {len(active)}")
    return active


# ─── Registrar IPs activas ───────────────────────────────────────────────────

def register_active_ips(active_ips: list[str]):
    if not active_ips:
        return

    print("\n── Registrando IPs activas en NetBox ──")
    existing = {
        ip["address"].split("/")[0]: ip
        for ip in api_get("/api/ipam/ip-addresses/")
    }

    created = updated = skipped = 0

    for raw_ip in active_ips:
        # Determinar prefijo /24
        net = ipaddress.ip_interface(f"{raw_ip}/24")
        address = str(net)          # ej. "192.168.8.10/24"

        if raw_ip in existing:
            rec = existing[raw_ip]
            if rec["status"]["value"] != "active":
                api_patch(f"/api/ipam/ip-addresses/{rec['id']}/", {"status": "active"})
                print(f"  [~]   {address} — marcado active")
                updated += 1
            else:
                skipped += 1
        else:
            api_post("/api/ipam/ip-addresses/", {
                "address": address,
                "status":  "active",
            })
            print(f"  [+]   {address} — creado")
            created += 1

    print(f"\n  Creados: {created}  |  Actualizados: {updated}  |  Ya existían: {skipped}")


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    print(f"NetBox: {NETBOX_URL}")
    try:
        requests.get(f"{NETBOX_URL}/api/", headers=HEADERS, timeout=5).raise_for_status()
    except Exception:
        sys.exit("No se puede conectar a NetBox. ¿Está corriendo Docker?")

    # 1. Registrar prefijos
    ensure_prefixes()

    # 2. Escanear ambas redes
    all_active = []
    for cfg in PREFIXES:
        activos = scan_subnet(cfg["prefix"])
        all_active.extend(activos)

    # 3. Registrar IPs activas
    register_active_ips(all_active)

    # 4. Resumen final
    print(f"\n{'═'*50}")
    print(f"  Total IPs activas: {len(all_active)}")
    for ip in sorted(all_active, key=lambda x: ipaddress.ip_address(x)):
        print(f"    {ip}")


if __name__ == "__main__":
    main()
