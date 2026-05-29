#!/bin/sh

SOCKET="/var/run/netifyd/netifyd.sock"
DHCP_LEASES="/tmp/dhcp.leases"

DATA=$(python3 -c "
import sys, socket, select, time, json, os
sock_path = '$SOCKET'
dhcp_path = '$DHCP_LEASES'
def load_hostnames(path):
    names = {}
    try:
        with open(path) as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 4:
                    ip, name = parts[2], parts[3]
                    if name not in ('*', ''):
                        names[ip] = name
    except:
        pass
    return names
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(sock_path)
sock.setblocking(False)
buf = b''
start = time.time()
while time.time() - start < 8:
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
    nl = buf.find(b'\\n', pos)
    if nl == -1:
        break
    try:
        header = json.loads(buf[pos:nl])
    except:
        pos = nl + 1
        continue
    pos = nl + 1
    if 'length' in header:
        n = header['length']
        payload = buf[pos:pos+n]
        pos += n
        if pos < len(buf) and buf[pos:pos+1] == b'\\n':
            pos += 1
        try:
            messages.append(json.loads(payload))
        except:
            pass
hostnames = load_hostnames(dhcp_path)
proto_count = {}
device_data = {}
for m in messages:
    if m.get('type') not in ('flow', 'flow_stats'):
        continue
    f = m.get('flow', {})
    proto = f.get('detected_protocol_name', 'Unknown')
    app = f.get('detected_application_name', 'Unknown')
    local_ip = f.get('local_ip', '?')
    label = (app if app and app != 'Unknown' else proto).replace('netify.', '')
    proto_count[label] = proto_count.get(label, 0) + 1
    if local_ip not in device_data:
        device_data[local_ip] = {'apps': {}, 'flows': 0}
    device_data[local_ip]['apps'][label] = device_data[local_ip]['apps'].get(label, 0) + 1
    device_data[local_ip]['flows'] += 1
total = sum(proto_count.values())
result = {
    'total': total,
    'devices': len(device_data),
    'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
    'protocols': sorted(proto_count.items(), key=lambda x: -x[1])[:15],
    'devices_list': sorted(device_data.items(), key=lambda x: -x[1]['flows'])
}
for ip, data in device_data.items():
    data['name'] = hostnames.get(ip, ip)
    data['top_apps'] = sorted(data['apps'].items(), key=lambda x: -x[1])[:3]
print(json.dumps(result))
" 2>&1)

echo "Content-Type: text/html; charset=UTF-8"
echo ""

if [ -z "$DATA" ]; then
    cat << HTMLBLOCK
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="10">
<title>DPI Report - Error</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #1a1a2e; color: #eee; display: flex; justify-content: center; align-items: center; height: 100vh; }
.card { background: #16213e; border-radius: 12px; padding: 40px; text-align: center; box-shadow: 0 10px 30px rgba(0,0,0,0.3); }
.error { color: #ff6b6b; font-size: 48px; margin-bottom: 20px; }
h2 { color: #fff; margin: 0; }
p { color: #aaa; margin-top: 10px; }
</style>
</head>
<body>
<div class="card">
<div class="error">&#9888;</div>
<h2>DPI Report Unavailable</h2>
<p>netifyd is not running or collecting data yet.</p>
<p style="font-size:12px;color:#666;">Auto-refreshing every 10s...</p>
</div>
</body>
</html>
HTMLBLOCK
    exit 0
fi

python3 -c "
import json, html, sys
data = json.loads('''${DATA}''')
total = data['total']
devices = data['devices']
ts = data['timestamp']
protocols = data['protocols']
devices_list = data['devices_list']
max_count = max(total, 1)

print('''<!DOCTYPE html>
<html lang=\"en\">
<head>
<meta charset=\"UTF-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
<meta http-equiv=\"refresh\" content=\"30\">
<title>DPI Report - Flint-2</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto, sans-serif; background: #1a1a2e; color: #e0e0e0; padding: 20px; }
.container { max-width: 1100px; margin: 0 auto; }
.header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); border-radius: 12px; padding: 25px 30px; margin-bottom: 20px; box-shadow: 0 4px 15px rgba(0,0,0,0.2); }
.header h1 { color: #fff; font-size: 24px; }
.header .subtitle { color: rgba(255,255,255,0.8); font-size: 13px; margin-top: 5px; }
.stats-row { display: flex; gap: 15px; margin-bottom: 20px; }
.stat-card { background: #16213e; border-radius: 10px; padding: 20px; flex: 1; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,0.2); }
.stat-card .num { font-size: 32px; font-weight: bold; color: #667eea; }
.stat-card .label { font-size: 12px; color: #888; margin-top: 5px; text-transform: uppercase; letter-spacing: 1px; }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
.card { background: #16213e; border-radius: 10px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.2); }
.card h2 { font-size: 16px; color: #667eea; margin-bottom: 15px; padding-bottom: 8px; border-bottom: 1px solid #2a2a4a; }
.bar-row { display: flex; align-items: center; margin-bottom: 6px; font-size: 13px; }
.bar-label { width: 130px; text-align: right; padding-right: 10px; color: #ccc; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.bar-bg { flex: 1; height: 20px; background: #2a2a4a; border-radius: 4px; overflow: hidden; }
.bar-fill { height: 100%; background: linear-gradient(90deg, #667eea, #764ba2); border-radius: 4px; min-width: 2px; }
.bar-count { width: 60px; text-align: right; padding-left: 8px; color: #aaa; font-size: 12px; }
.device-row { display: flex; align-items: center; padding: 8px 0; border-bottom: 1px solid #1f1f3a; font-size: 13px; }
.device-row:last-child { border-bottom: none; }
.device-name { width: 200px; font-weight: 500; color: #ddd; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.device-flows { width: 60px; color: #667eea; text-align: center; }
.device-apps { flex: 1; color: #888; font-size: 12px; }
.badge { display: inline-block; background: #2a2a4a; padding: 1px 6px; border-radius: 4px; margin-right: 4px; font-size: 11px; color: #aab; }
.footer { text-align: center; padding: 20px; color: #555; font-size: 12px; }
.footer a { color: #667eea; text-decoration: none; }
@media (max-width: 768px) {
  .grid { grid-template-columns: 1fr; }
  .stats-row { flex-wrap: wrap; }
  .bar-label { width: 90px; font-size: 12px; }
  .device-name { width: 140px; }
}
</style>
</head>
<body>
<div class=\"container\">
<div class=\"header\">
<h1>&#128200; DPI Report &mdash; Flint-2</h1>
<div class=\"subtitle\">Actualizado: ''' + ts + ''' UTC &middot; Auto-refresh cada 30s</div>
</div>
<div class=\"stats-row\">
<div class=\"stat-card\"><div class=\"num\">''' + str(total) + '''</div><div class=\"label\">Flows</div></div>
<div class=\"stat-card\"><div class=\"num\">''' + str(devices) + '''</div><div class=\"label\">Dispositivos</div></div>
<div class=\"stat-card\"><div class=\"num\">''' + str(len(protocols)) + '''</div><div class=\"label\">Protocolos</div></div>
</div>
<div class=\"grid\">
<div class=\"card\">
<h2>Top Protocolos / Apps</h2>''')

for p, c in protocols:
    pct = int(c * 100 / max_count)
    bar_pct = int(c * 100 / max_count)
    print('<div class=\"bar-row\"><div class=\"bar-label\">{}</div><div class=\"bar-bg\"><div class=\"bar-fill\" style=\"width:{}%\"></div></div><div class=\"bar-count\">{} ({}%)</div></div>'.format(html.escape(p), bar_pct, c, pct))

print('''</div>
<div class=\"card\">
<h2>Dispositivos</h2>''')

for ip, dev_data in devices_list[:15]:
    name = dev_data['name']
    flows = dev_data['flows']
    top_apps = dev_data.get('top_apps', [])
    apps_str = ' '.join('<span class=\"badge\">{}</span>'.format(html.escape(a)) for a, _ in top_apps)
    print('<div class=\"device-row\"><div class=\"device-name\">{}</div><div class=\"device-flows\">{}</div><div class=\"device-apps\">{}</div></div>'.format(html.escape(name), flows, apps_str))

print('''</div>
</div>
<div class=\"footer\">
<a href=\"cgi-bin/luci/\">LuCI</a> &middot; 
<a href=\"unbound-dashboard/\">Unbound DNS</a> &middot; 
netifyd DPI
</div>
</div>
</body>
</html>''')
" 2>&1
