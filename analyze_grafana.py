#!/usr/bin/env python3
import requests
import json

GRAFANA_URL = "https://ja16779.grafana.net"
TOKEN = "REDACTED_GRAFANA_TOKEN"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

def get_dashboards():
    """Obtener lista de todos los dashboards"""
    resp = requests.get(f"{GRAFANA_URL}/api/search?type=dash-db&limit=100", headers=HEADERS)
    if resp.status_code == 200:
        return resp.json()
    else:
        print(f"Error al obtener dashboards: {resp.status_code}")
        print(resp.text)
        return []

def get_dashboard_detail(uid):
    """Obtener detalle de un dashboard específico"""
    resp = requests.get(f"{GRAFANA_URL}/api/dashboards/uid/{uid}", headers=HEADERS)
    if resp.status_code == 200:
        return resp.json()
    return None

def get_folders():
    """Obtener lista de carpetas"""
    resp = requests.get(f"{GRAFANA_URL}/api/folders", headers=HEADERS)
    if resp.status_code == 200:
        return resp.json()
    return []

def analyze_dashboard(db):
    """Analizar un dashboard y devolver estadísticas"""
    dashboard = db.get('dashboard', {})
    title = dashboard.get('title', 'Sin título')
    panels = dashboard.get('panels', [])
    
    analysis = {
        'title': title,
        'uid': dashboard.get('uid'),
        'panel_count': len(panels),
        'rows': [],
        'panels_by_type': {},
        'variables': len(dashboard.get('templating', {}).get('list', [])),
        'tags': dashboard.get('tags', []),
        'refresh': dashboard.get('refresh'),
        'time_from': dashboard.get('time', {}).get('from'),
    }
    
    # Analizar filas y paneles
    for panel in panels:
        if panel.get('type') == 'row':
            analysis['rows'].append({
                'title': panel.get('title', 'Sin nombre'),
                'collapsed': panel.get('collapsed', False),
                'panels_inside': len([p for p in panels if p.get('gridPos', {}).get('y', 0) > panel.get('gridPos', {}).get('y', 0)])
            })
        else:
            ptype = panel.get('type', 'unknown')
            analysis['panels_by_type'][ptype] = analysis['panels_by_type'].get(ptype, 0) + 1
    
    return analysis

def main():
    print("=" * 70)
    print("ANÁLISIS DE GRAFANA CLOUD - ja16779.grafana.net")
    print("=" * 70)
    
    # Obtener carpetas
    print("\n📁 CARPETAS:")
    folders = get_folders()
    if folders:
        for f in folders:
            print(f"  - {f['title']} (ID: {f['id']}, UID: {f['uid']})")
    else:
        print("  (No hay carpetas personalizadas - todo está en General)")
    
    # Obtener dashboards
    print("\n" + "=" * 70)
    print("📊 DASHBOARDS ENCONTRADOS:")
    print("=" * 70)
    
    dashboards = get_dashboards()
    print(f"Total: {len(dashboards)} dashboards\n")
    
    all_analysis = []
    
    for db_info in dashboards:
        title = db_info.get('title', 'Sin título')
        uid = db_info.get('uid')
        folder = db_info.get('folderTitle', 'General')
        
        print(f"🔹 {title}")
        print(f"   Folder: {folder} | UID: {uid} | Tipo: {db_info.get('type', 'N/A')}")
        
        # Obtener detalle completo
        detail = get_dashboard_detail(uid)
        if detail:
            analysis = analyze_dashboard(detail)
            all_analysis.append(analysis)
            
            print(f"   Paneles: {analysis['panel_count']} | Variables: {analysis['variables']}")
            print(f"   Tags: {', '.join(analysis['tags']) if analysis['tags'] else 'Ninguno'}")
            print(f"   Refresh: {analysis['refresh'] or 'Manual'}")
            
            if analysis['rows']:
                print(f"   Filas ({len(analysis['rows'])}):")
                for row in analysis['rows']:
                    status = "📂" if row['collapsed'] else "📂 abierto"
                    print(f"      {status} {row['title']}")
            
            if analysis['panels_by_type']:
                print(f"   Tipos de paneles:")
                for ptype, count in sorted(analysis['panels_by_type'].items(), key=lambda x: -x[1]):
                    print(f"      - {ptype}: {count}")
        print()
    
    # Resumen y recomendaciones
    print("=" * 70)
    print("📋 RESUMEN Y RECOMENDACIONES")
    print("=" * 70)
    
    # Análisis de organización
    folder_titles = set([d.get('folderTitle', 'General') for d in dashboards])
    
    print("\n1. ORGANIZACIÓN POR CARPETAS:")
    if len(folder_titles) <= 1:
        print("   ⚠️  Todos los dashboards están en 'General'")
        print("   💡 RECOMENDACIÓN: Crear carpetas temáticas como:")
        print("      - 'Network / Infraestructura'")
        print("      - 'Sistema / Servidores'")
        print("      - 'Aplicaciones'")
        print("      - 'Seguridad'")
    else:
        print(f"   ✓ Tienes {len(folder_titles)} carpetas: {', '.join(folder_titles)}")
    
    # Análisis de tags
    print("\n2. USO DE TAGS:")
    all_tags = set()
    for a in all_analysis:
        all_tags.update(a['tags'])
    
    if not all_tags:
        print("   ⚠️  No se encontraron tags en los dashboards")
        print("   💡 RECOMENDACIÓN: Agregar tags como 'openwrt', 'network', 'wifi', 'wan', 'system'")
    else:
        print(f"   ✓ Tags usados: {', '.join(sorted(all_tags))}")
    
    # Análisis de refresh
    print("\n3. CONFIGURACIÓN DE REFRESH:")
    auto_refresh = [a for a in all_analysis if a['refresh']]
    manual = [a for a in all_analysis if not a['refresh']]
    
    print(f"   Auto-refresh: {len(auto_refresh)} dashboards")
    print(f"   Manual: {len(manual)} dashboards")
    
    # Análisis de variables
    print("\n4. USO DE VARIABLES:")
    dashboards_with_vars = [a for a in all_analysis if a['variables'] > 0]
    if dashboards_with_vars:
        print(f"   ✓ {len(dashboards_with_vars)} dashboards usan variables")
        for d in dashboards_with_vars:
            print(f"      - {d['title']}: {d['variables']} variables")
    else:
        print("   ⚠️  Ningún dashboard usa variables")
        print("   💡 RECOMENDACIÓN: Agregar variables como 'instance', 'job', 'interface'")
    
    print("\n" + "=" * 70)
    print("ANÁLISIS COMPLETADO")
    print("=" * 70)

if __name__ == "__main__":
    main()