# luci-app-linkmonitor

Network link monitoring application for OpenWrt with configurable alerts.

Monitor the status of network hosts and services via Ping, HTTP/HTTPS and DNS checks directly from your router. Get notified instantly when a link goes down or recovers through syslog, email, custom scripts or webhooks.

## Features

- **Multiple check methods**: Ping (ICMP), HTTP/HTTPS response, DNS lookup
- **4 alert types**: Syslog, Email (sendmail/msmtp), Custom script, Webhook (HTTP POST JSON)
- **Configurable triggers**: Alert on link down, recovery, or both
- **Real-time dashboard**: Status cards with latency bars, uptime tracking and event history
- **Manual test**: Test any link on-demand from the web interface
- **Per-link intervals**: Each link can have its own check interval
- **Procd integration**: Daemon auto-restarts on failure, reloads on config change

## Requirements

- OpenWrt 21.02 or later (LuCI2 with client-side JS views)
- `curl` (for HTTP/HTTPS checks and webhook alerts)
- `sendmail` or `msmtp` (optional, only for email alerts)

## Installation

### Option A: Direct copy to router (quick)

1. Transfer the files to your router:

```bash
scp -r root/* root@192.168.1.1:/
scp -r htdocs/* root@192.168.1.1:/www/
```

2. Set permissions and activate:

```bash
ssh root@192.168.1.1
chmod +x /usr/bin/linkmonitor-daemon
chmod +x /usr/libexec/rpcd/linkmonitor
chmod +x /etc/init.d/linkmonitor
/etc/init.d/rpcd reload
/etc/init.d/linkmonitor enable
/etc/init.d/linkmonitor start
```

3. Open LuCI in your browser and navigate to **Network > Link Monitor**.

### Option B: Build as .ipk package

1. Copy the entire `luci-app-linkmonitor` directory into your OpenWrt build tree:

```bash
cp -r luci-app-linkmonitor/ /path/to/openwrt/feeds/luci/applications/
```

2. Update feeds and select the package:

```bash
./scripts/feeds update luci
./scripts/feeds install luci-app-linkmonitor
make menuconfig
# Navigate to: LuCI > 3. Applications > luci-app-linkmonitor [*]
```

3. Build:

```bash
make package/luci-app-linkmonitor/compile V=s
```

4. Install the resulting `.ipk` on the router:

```bash
opkg install /tmp/luci-app-linkmonitor_1.0.0-1_all.ipk
```

## Usage

### Web interface

After installation, go to **Network > Link Monitor** in LuCI. You will find two tabs:

#### Overview

The main dashboard shows:

- **Daemon status**: Whether the monitoring daemon is running, its PID and uptime. You can restart it from here.
- **Link cards**: One card per monitored host showing current state (UP/DOWN), latency with a color-coded bar, time since last check, time since last state change, and consecutive failure count. Each card has a **Test** button to run an immediate check.
- **Event history**: Table of state-change events (timestamp, link name, host, state, latency) with a button to clear all history.

#### Configuration

The configuration page has three sections:

**Global Settings**

| Option | Description | Default |
|---|---|---|
| Enable Monitoring | Master switch for the daemon | Enabled |
| Default Check Interval | Seconds between checks (links can override) | 30 |
| History Size | Max events to retain | 200 |

**Monitored Links**

Add, remove and reorder links to monitor. Each link has:

| Option | Description |
|---|---|
| Enabled | Toggle this link on/off |
| Name | Descriptive label (e.g. "WAN Gateway") |
| Host / URL | IP, hostname, or full URL to check |
| Method | `Ping (ICMP)`, `HTTP/HTTPS`, or `DNS Lookup` |
| Interval | Per-link override in seconds (empty = global) |
| Timeout | Seconds before a check is considered failed |
| Retries | Ping attempts before declaring failure (ping only) |

**Alert Rules**

Add, remove and reorder alert actions. Each alert has:

| Option | Description |
|---|---|
| Enabled | Toggle this alert on/off |
| Name | Descriptive label (e.g. "Email Admin") |
| Type | `Syslog`, `Email`, `Custom Script`, or `Webhook` |
| Trigger On | `Both`, `Link Down Only`, or `Link Recovery Only` |

Additional options depending on type:

- **Email**: Recipient address, subject prefix. Requires `sendmail` or `msmtp` installed.
- **Script**: Full path to an executable script. Called with arguments: `<name> <host> <state> <latency>`.
- **Webhook**: URL that receives a POST request with JSON body:
  ```json
  {
    "link": "WAN Gateway",
    "host": "8.8.8.8",
    "state": "down",
    "latency": 0,
    "time": "2025-01-15T10:30:00"
  }
  ```

### Command line

Start, stop or check the daemon via init script:

```bash
/etc/init.d/linkmonitor start
/etc/init.d/linkmonitor stop
/etc/init.d/linkmonitor restart
/etc/init.d/linkmonitor status
```

View live monitoring logs:

```bash
logread -f | grep linkmonitor
```

Check current link status directly:

```bash
cat /tmp/linkmonitor/status.json
```

View event history:

```bash
cat /tmp/linkmonitor/history.json
```

Edit configuration from the command line:

```bash
# Add a new link
uci add linkmonitor link
uci set linkmonitor.@link[-1].enabled='1'
uci set linkmonitor.@link[-1].name='My Server'
uci set linkmonitor.@link[-1].host='10.0.0.1'
uci set linkmonitor.@link[-1].method='ping'
uci set linkmonitor.@link[-1].timeout='5'
uci set linkmonitor.@link[-1].retries='3'
uci commit linkmonitor
/etc/init.d/linkmonitor restart

# Add a webhook alert
uci add linkmonitor alert
uci set linkmonitor.@alert[-1].enabled='1'
uci set linkmonitor.@alert[-1].name='Slack Webhook'
uci set linkmonitor.@alert[-1].type='webhook'
uci set linkmonitor.@alert[-1].trigger='down'
uci set linkmonitor.@alert[-1].url='https://hooks.slack.com/services/xxx'
uci commit linkmonitor
/etc/init.d/linkmonitor restart
```

### Custom alert script example

Create `/usr/bin/linkmonitor-alert.sh`:

```bash
#!/bin/sh
# Arguments: $1=name $2=host $3=state $4=latency
NAME="$1"
HOST="$2"
STATE="$3"
LATENCY="$4"

if [ "$STATE" = "down" ]; then
    # Blink router LED as visual alert
    echo timer > /sys/class/leds/green:power/trigger
    echo 100 > /sys/class/leds/green:power/delay_on
    echo 100 > /sys/class/leds/green:power/delay_off
else
    # Restore LED to default
    echo default-on > /sys/class/leds/green:power/trigger
fi
```

```bash
chmod +x /usr/bin/linkmonitor-alert.sh
```

## File structure

```
luci-app-linkmonitor/
├── Makefile                                          # OpenWrt package definition
├── README.md
├── htdocs/luci-static/resources/view/linkmonitor/
│   ├── overview.js                                   # Dashboard view (status, history)
│   └── config.js                                     # Configuration view (UCI form)
└── root/
    ├── etc/
    │   ├── config/linkmonitor                        # UCI config with defaults
    │   ├── init.d/linkmonitor                        # Procd init script
    │   └── uci-defaults/40_luci-linkmonitor          # Post-install setup
    └── usr/
        ├── bin/linkmonitor-daemon                    # Monitoring daemon
        ├── libexec/rpcd/linkmonitor                  # RPCd ubus backend
        └── share/
            ├── luci/menu.d/luci-app-linkmonitor.json # LuCI menu entry
            └── rpcd/acl.d/luci-app-linkmonitor.json  # RPCd ACL permissions
```

## Uninstall

If installed via `.ipk`:

```bash
opkg remove luci-app-linkmonitor
```

If installed manually:

```bash
/etc/init.d/linkmonitor stop
/etc/init.d/linkmonitor disable
rm -f /usr/bin/linkmonitor-daemon
rm -f /usr/libexec/rpcd/linkmonitor
rm -f /etc/init.d/linkmonitor
rm -f /etc/config/linkmonitor
rm -f /etc/uci-defaults/40_luci-linkmonitor
rm -f /usr/share/luci/menu.d/luci-app-linkmonitor.json
rm -f /usr/share/rpcd/acl.d/luci-app-linkmonitor.json
rm -rf /www/luci-static/resources/view/linkmonitor
rm -rf /tmp/linkmonitor
/etc/init.d/rpcd reload
```

## License

GPL-3.0-or-later
