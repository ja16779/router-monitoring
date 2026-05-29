#!/usr/bin/python3
"""DPI Report CGI - generates HTML dashboard or JSON data from netifyd socket."""

import sys
import json
import html
import socket
import select
import time
import os

SOCKET_PATH = "/var/run/netifyd/netifyd.sock"
DHCP_LEASES = "/tmp/dhcp.leases"

def load_hostnames(path):
    names = {}
    try:
        with open(path) as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 4:
                    ip, name = parts[2], parts[3]
                    if name not in ("*", ""):
                        names[ip] = name
    except Exception:
        pass
    return names

def read_netifyd(sock_path, duration=8):
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(sock_path)
        sock.setblocking(False)
    except Exception as e:
        return None, str(e)
    buf = b""
    start = time.time()
    while time.time() - start < duration:
        ready = select.select([sock], [], [], 1)
        if ready[0]:
            data = sock.recv(262144)
            if not data:
                break
            buf += data
    sock.close()
    pos = 0
    messages = []
    while pos < len(buf):
        nl = buf.find(b"\n", pos)
        if nl == -1:
            break
        try:
            header = json.loads(buf[pos:nl])
        except Exception:
            pos = nl + 1
            continue
        pos = nl + 1
        if "length" in header:
            n = header["length"]
            payload = buf[pos : pos + n]
            pos += n
            if pos < len(buf) and buf[pos : pos + 1] == b"\n":
                pos += 1
            try:
                messages.append(json.loads(payload))
            except Exception:
                pass
    return messages, None

def analyze(messages):
    proto_count = {}
    device_data = {}
    for m in messages:
        if m.get("type") not in ("flow", "flow_stats"):
            continue
        f = m.get("flow", {})
        proto = f.get("detected_protocol_name", "Unknown")
        app = f.get("detected_application_name", "Unknown")
        local_ip = f.get("local_ip", "?")
        label = (app if app and app != "Unknown" else proto).replace("netify.", "")
        proto_count[label] = proto_count.get(label, 0) + 1
        if local_ip not in device_data:
            device_data[local_ip] = {"apps": {}, "flows": 0}
        device_data[local_ip]["apps"][label] = device_data[local_ip]["apps"].get(label, 0) + 1
        device_data[local_ip]["flows"] += 1
    return proto_count, device_data

def render_html(total, devices, ts, protocols, devices_list):
    max_count = max(total, 1)

    proto_rows = ""
    for p, c in protocols:
        pct = int(c * 100 / max_count)
        proto_rows += (
            '<div class="bar-row">'
            f'<div class="bar-label">{html.escape(p)}</div>'
            f'<div class="bar-bg"><div class="bar-fill" style="width:{pct}%"></div></div>'
            f'<div class="bar-count">{c} ({pct}%)</div>'
            "</div>"
        )

    device_rows = ""
    for ip, dev_data in devices_list[:15]:
        name = dev_data["name"]
        flows = dev_data["flows"]
        top = dev_data.get("top_apps", [])
        if top and isinstance(top[0], (list, tuple)):
            apps_str = " ".join(
                f'<span class="badge">{html.escape(a)}</span>' for a, _ in top
            )
        else:
            apps_str = " ".join(
                f'<span class="badge">{html.escape(a)}</span>' for a in top
            )
        device_rows += (
            '<div class="device-row">'
            f'<div class="device-name">{html.escape(name)}</div>'
            f'<div class="device-flows">{flows}</div>'
            f'<div class="device-apps">{apps_str}</div>'
            "</div>"
        )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="30">
<title>DPI Report - Flint-2</title>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #1a1a2e; color: #fff; padding: 20px; }}
.container {{ max-width: 1100px; margin: 0 auto; }}
.header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px; padding: 25px 30px; margin-bottom: 20px; box-shadow: 0 4px 15px rgba(0,0,0,0.2); }}
.header h1 {{ color: #fff; font-size: 24px; }}
.header .subtitle {{ color: #fff; font-size: 13px; margin-top: 5px; }}
.stats-row {{ display: flex; gap: 15px; margin-bottom: 20px; }}
.stat-card {{ background: #16213e; border-radius: 10px; padding: 20px; flex: 1; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,0.2); }}
.stat-card .num {{ font-size: 32px; font-weight: bold; color: #fff; }}
.stat-card .label {{ font-size: 12px; color: #fff; margin-top: 5px; text-transform: uppercase; letter-spacing: 1px; }}
.grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }}
.card {{ background: #16213e; border-radius: 10px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.2); }}
.card h2 {{ font-size: 16px; color: #fff; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 1px solid #2a2a4a; }}
.bar-row {{ display: flex; align-items: center; margin-bottom: 6px; font-size: 13px; }}
.bar-label {{ width: 130px; text-align: right; padding-right: 10px; color: #fff; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }}
.bar-bg {{ flex: 1; height: 20px; background: #2a2a4a; border-radius: 4px; overflow: hidden; }}
.bar-fill {{ height: 100%; background: linear-gradient(90deg, #667eea, #764ba2); border-radius: 4px; min-width: 2px; }}
.bar-count {{ width: 60px; text-align: right; padding-left: 8px; color: #fff; font-size: 12px; }}
.device-row {{ display: flex; align-items: center; padding: 8px 0; border-bottom: 1px solid #1f1f3a; font-size: 13px; }}
.device-row:last-child {{ border-bottom: none; }}
.device-name {{ width: 200px; font-weight: 500; color: #fff; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }}
.device-flows {{ width: 60px; color: #fff; text-align: center; }}
.device-apps {{ flex: 1; color: #fff; font-size: 12px; }}
.badge {{ display: inline-block; background: #3a3a5a; padding: 1px 6px; border-radius: 4px; margin-right: 4px; font-size: 11px; color: #fff; }}
.footer {{ text-align: center; padding: 20px; color: #fff; font-size: 12px; }}
.footer a {{ color: #fff; text-decoration: none; }}
@media (max-width: 768px) {{
  .grid {{ grid-template-columns: 1fr; }}
  .stats-row {{ flex-wrap: wrap; }}
  .bar-label {{ width: 90px; font-size: 12px; }}
  .device-name {{ width: 140px; }}
}}
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>&#128200; DPI Report &mdash; Flint-2</h1>
<div class="subtitle">Actualizado: {ts} UTC &middot; Auto-refresh cada 30s</div>
</div>
<div class="stats-row">
<div class="stat-card"><div class="num">{total}</div><div class="label">Flows</div></div>
<div class="stat-card"><div class="num">{devices}</div><div class="label">Dispositivos</div></div>
<div class="stat-card"><div class="num">{len(protocols)}</div><div class="label">Protocolos</div></div>
</div>
<div class="grid">
<div class="card">
<h2>Top Protocolos / Apps</h2>
{proto_rows}
</div>
<div class="card">
<h2>Dispositivos</h2>
{device_rows}
</div>
</div>
<div class="footer">
<a href="/cgi-bin/luci/">LuCI</a> &middot;
<a href="/unbound-dashboard/">Unbound DNS</a> &middot;
netifyd DPI
</div>
</div>
</body>
</html>"""

def collect_data():
    messages, error = read_netifyd(SOCKET_PATH)
    if messages is None:
        return None
    hostnames = load_hostnames(DHCP_LEASES)
    proto_count, device_data = analyze(messages)
    total = sum(proto_count.values())
    protocols = sorted(proto_count.items(), key=lambda x: -x[1])[:15]
    devices_list = sorted(device_data.items(), key=lambda x: -x[1]["flows"])
    for ip, data in device_data.items():
        data["name"] = hostnames.get(ip, ip)
        data["top_apps"] = sorted(data["apps"].items(), key=lambda x: -x[1])[:3]
    return {
        "total": total,
        "devices": len(device_data),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "protocols": [(p, c) for p, c in protocols],
        "devices_list": [
            {"ip": ip, "name": d["name"], "flows": d["flows"], "top_apps": [a for a, _ in d["top_apps"]]}
            for ip, d in devices_list[:15]
        ]
    }

def render_error():
    return """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="10">
<title>DPI Report - Error</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #1a1a2e; color: #fff; display: flex; justify-content: center; align-items: center; height: 100vh; }
.card { background: #16213e; border-radius: 12px; padding: 40px; text-align: center; box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
.error { color: #ff6b6b; font-size: 48px; margin-bottom: 20px; }
h2 { color: #fff; margin: 0; }
p { color: #fff; margin-top: 10px; }
</style>
</head>
<body>
<div class="card">
<div class="error">&#9888;</div>
<h2>DPI Report Unavailable</h2>
<p>netifyd is not running or collecting data yet.</p>
<p style="font-size:12px;color:#fff;">Auto-refreshing every 10s...</p>
</div>
</body>
</html>"""

def get_query():
    env_query = os.environ.get("QUERY_STRING", "")
    return env_query

def main():
    query = get_query()
    is_json = "format=json" in query

    data = collect_data()

    if is_json:
        print("Content-Type: application/json; charset=UTF-8")
        print()
        if data is None:
            print(json.dumps({"error": "netifyd not available"}))
        else:
            print(json.dumps(data))
        return

    print("Content-Type: text/html; charset=UTF-8")
    print()

    if data is None:
        print(render_error())
        return

    ts = data["timestamp"]
    total = data["total"]
    devices = data["devices"]
    protocols = data["protocols"]
    devices_list = data["devices_list"]

    hostnames = {d["ip"]: d["name"] for d in devices_list}
    proto_items = [(p, c) for p, c in protocols]
    dev_items = [(d["ip"], {"name": d["name"], "flows": d["flows"], "top_apps": d["top_apps"]}) for d in devices_list]

    print(render_html(total, devices, ts, proto_items, dev_items))

if __name__ == "__main__":
    main()
