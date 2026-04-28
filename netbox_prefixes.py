#!/usr/bin/env python3
"""
netbox_prefixes.py — Consulta prefijos activos en NetBox via API
Uso: python netbox_prefixes.py [--parent 10.0.0.0/8] [--role infraestructura]
"""

import argparse
import ipaddress
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
}


def get_prefixes(params: dict) -> list:
    """Pagina automáticamente por todos los resultados."""
    url = f"{NETBOX_URL}/api/ipam/prefixes/"
    results = []
    while url:
        r = requests.get(url, headers=HEADERS, params=params, timeout=10)
        r.raise_for_status()
        data = r.json()
        results.extend(data["results"])
        url = data.get("next")
        params = {}          # next ya lleva los query params en la URL
    return results


def utilization(prefix: dict) -> str:
    """Devuelve el % de IPs utilizadas si NetBox lo expone."""
    u = prefix.get("utilization")
    return f"{u}%" if u is not None else "N/A"


def print_table(prefixes: list):
    if not prefixes:
        print("Sin resultados.")
        return

    # Cabecera
    print(f"\n{'Prefijo':<22} {'Status':<12} {'VRF':<14} {'Site':<16} {'Role':<18} {'Uso':<6} Descripción")
    print("-" * 110)

    for p in prefixes:
        prefix   = p["prefix"]
        status   = p["status"]["label"]
        vrf      = (p["vrf"] or {}).get("name", "-")
        site     = (p["site"] or {}).get("name", "-")
        role     = (p["role"] or {}).get("name", "-")
        desc     = p.get("description", "")
        uso      = utilization(p)

        print(f"{prefix:<22} {status:<12} {vrf:<14} {site:<16} {role:<18} {uso:<6} {desc}")

    print(f"\nTotal: {len(prefixes)} prefijos")


def main():
    parser = argparse.ArgumentParser(description="Consulta prefijos activos en NetBox")
    parser.add_argument("--parent",  help="Filtrar por prefijo padre (ej. 10.0.0.0/8)")
    parser.add_argument("--role",    help="Filtrar por role (ej. infraestructura)")
    parser.add_argument("--site",    help="Filtrar por site")
    parser.add_argument("--vrf",     help="Filtrar por VRF name")
    parser.add_argument("--status",  default="active",
                        help="Status: active | reserved | deprecated | container (default: active)")
    parser.add_argument("--all",     action="store_true",
                        help="Mostrar todos los status")
    args = parser.parse_args()

    params = {}
    if not args.all:
        params["status"] = args.status
    if args.parent:
        # Validar el prefijo
        try:
            ipaddress.ip_network(args.parent, strict=False)
        except ValueError:
            sys.exit(f"Prefijo inválido: {args.parent}")
        params["within_include"] = args.parent   # incluye el padre + hijos
    if args.role:
        params["role"] = args.role
    if args.site:
        params["site"] = args.site
    if args.vrf:
        params["vrf"] = args.vrf

    print(f"Consultando NetBox ({NETBOX_URL})…")
    try:
        prefixes = get_prefixes(params)
    except requests.exceptions.ConnectionError:
        sys.exit("No se puede conectar a NetBox. ¿Está corriendo Docker?")
    except requests.exceptions.HTTPError as e:
        sys.exit(f"Error API: {e}")

    print_table(prefixes)


if __name__ == "__main__":
    main()
