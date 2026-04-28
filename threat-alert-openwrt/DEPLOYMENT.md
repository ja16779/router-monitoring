# Threat Alert System - Deployment Status

**Date:** 2026-04-14  
**Status:** ✅ DEPLOYED & OPERATIONAL  
**Router:** Flint-2 (GL-MT6000) @ 192.168.10.1  
**OpenWrt:** 25.12.2 (r32802-f505120278)

---

## 📦 Installation Summary

### What Was Installed

| Component | Location | Status |
|-----------|----------|--------|
| Scripts | `/usr/local/lib/threat-alert/` | ✅ 5 files |
| Configuration | `/etc/threat-alert/config.sh` | ✅ Configured |
| Logs | `/var/log/threat-alert/` | ✅ Directory created |
| Feeds | `/etc/threat-alert/feeds/` | ✅ Emerging Threats: 387 IPs |
| Symlinks | `/usr/local/bin/` | ✅ 3 commands available |
| Cron jobs | `/etc/crontabs/root` | ✅ 2 jobs scheduled |

### Files Installed

```
/usr/local/lib/threat-alert/
├── threat_feed_updater.sh    (240 lines) - Downloads threat intelligence feeds
├── anomaly_detector.sh       (190 lines) - Detects suspicious network patterns
├── security_monitor.sh       (300 lines) - Real-time threat level dashboard
├── config.sh                 (102 lines) - Configuration (sourced by all scripts)
└── install.sh                (180 lines) - Installation script
```

### Commands Available

```bash
# Check current threat level (one-time)
/usr/local/lib/threat-alert/security_monitor.sh --check

# Watch live threat dashboard
/usr/local/lib/threat-alert/security_monitor.sh --live

# Send test alert if threat detected
/usr/local/lib/threat-alert/security_monitor.sh --alert

# Download and update threat feeds manually
/usr/local/lib/threat-alert/threat_feed_updater.sh

# Run anomaly detection manually
/usr/local/lib/threat-alert/anomaly_detector.sh
```

---

## 🚨 Threat Feeds

### Emerging Threats C2 IPs
- **Status:** ✅ Downloaded (387 IPs)
- **Source:** https://rules.emergingthreats.net/blockrules/compromised-ips.txt
- **Last Updated:** 2026-04-14 21:04:53
- **File:** `/etc/threat-alert/feeds/emerging_c2_ips.txt`

### URLhaus Malware Domains
- **Status:** ⚠️ Failed to download
- **Reason:** Telmex ISP blocks abuse.ch URLs on eth1
- **Workaround:** Feeds are designed to gracefully degrade - system works with partial feeds
- **Fallback:** Can configure secondary DNS provider for URLhaus

---

## 📅 Automated Tasks

### Cron Jobs Configuration

```
# Every 12 hours at midnight and noon
0 */12 * * * /usr/local/lib/threat-alert/threat_feed_updater.sh >> /var/log/threat-alert/updater.log 2>&1

# Every 5 minutes
*/5 * * * * /usr/local/lib/threat-alert/anomaly_detector.sh >> /var/log/threat-alert/anomaly.log 2>&1
```

### Manual Scheduling

To verify or modify cron jobs:
```bash
ssh root@192.168.10.1
crontab -e
```

---

## 🎯 Security Features Active

### Threat Intelligence
- ✅ C2 IP blocking (387 IPs from Emerging Threats)
- ⚠️ Malware domain blocking (URLhaus unavailable, gracefully degraded)
- ✅ Feed auto-updates every 12 hours
- ✅ Telegram notifications on feed updates

### Anomaly Detection
- ✅ Port scanning detection (threshold: 20 unique ports per device)
- ✅ SSH brute force detection (threshold: 5 failed attempts)
- ✅ DNS query flooding detection (threshold: 100 queries in 10 seconds)
- ✅ Firewall block anomaly detection (detects suspicious surges)
- ✅ Telegram alerts for each anomaly type

### Real-time Monitoring
- ✅ **Threat Level Score (0-100)**
  - 0-19: 🟢 NORMAL
  - 20-49: 🟡 SOSPECHOSO
  - 50+: 🔴 CRÍTICO - POSIBLE ATAQUE

---

## 📊 Current Status (2026-04-14 21:04)

```
Threat Level: 🟢 NORMAL (0/100)
Firewall blocks: 0
SSH attempts: 0
Active connections: 12
Emerging Threats IPs loaded: 387
```

---

## 📝 Logs Location

All logs are stored in `/var/log/threat-alert/`:

```bash
# Feed update logs
tail -f /var/log/threat-alert/updater.log

# Anomaly detection logs
tail -f /var/log/threat-alert/anomaly.log

# Cron execution logs
tail -f /var/log/threat-alert/cron.log

# View all threats in real-time
grep "THREAT\|ALERT\|ANOMALY\|DETECTED" /var/log/threat-alert/*.log
```

---

## 🔧 Configuration Details

### Telegram Integration

- **Bot Token:** Configured from `/etc/monitor/config.sh`
- **Chat ID:** 716542586
- **Alerts Enabled:**
  - ✅ Feed update notifications
  - ✅ Anomaly detections (all types)
  - ✅ Manual test alerts

### DNS Integration

Current DNS architecture (unchanged by threat-alert):
```
Clients → AdGuardHome:53 → NextDNS DoT → 45.90.28.0/45.90.30.0 (fallback)
```

The threat-alert system works **independently** of DNS services and doesn't affect:
- AdGuardHome filtering
- dnsmasq DHCP
- NextDNS DoT resolution

---

## ⚙️ Maintenance Tasks

### Weekly
- [ ] Review threat logs: `grep ALERT /var/log/threat-alert/*.log`
- [ ] Check feed freshness: `ls -lt /etc/threat-alert/feeds/`
- [ ] Verify anomaly detection accuracy (check for false positives)

### Monthly
- [ ] Review threat trends in Telegram history
- [ ] Check feed update success rate
- [ ] Verify disk space: `df -h /var/log/`

### As Needed
- [ ] Test manual feed update: `/usr/local/lib/threat-alert/threat_feed_updater.sh`
- [ ] Reload config: Edit `/etc/threat-alert/config.sh` and restart cron
- [ ] Clear old logs: `rm -f /var/log/threat-alert/*.log.1`

---

## 🚀 Next Steps

### Phase 2 (Future)
- [ ] VLAN isolation for detected threats
- [ ] LuCI web dashboard
- [ ] Device-level threat tracking
- [ ] Integration with CrowdSec

### Known Issues
1. **URLhaus Feed Unavailable**
   - ISP blocks abuse.ch domain
   - **Workaround:** Use Emerging Threats feed (functional, 387 IPs)
   - **Alternative:** Configure VPN or alternative feed source

2. **Hostname not found**
   - Minor issue in alert messages
   - **Impact:** None (alerts still send)
   - **Status:** Cosmetic only

---

## 📞 Support

### View Live Dashboard
```bash
ssh root@192.168.10.1 /usr/local/lib/threat-alert/security_monitor.sh --live
```

### Check Recent Alerts
```bash
ssh root@192.168.10.1
grep "ALERT\|CRITICAL\|DETECTED" /var/log/threat-alert/*.log | tail -20
```

### Manually Trigger Alert
```bash
ssh root@192.168.10.1 /usr/local/lib/threat-alert/security_monitor.sh --alert
```

### Debug Feed Update
```bash
ssh root@192.168.10.1
LOG_LEVEL=DEBUG /usr/local/lib/threat-alert/threat_feed_updater.sh
```

---

## 📋 Deployment Checklist

- [x] Scripts installed to `/usr/local/lib/threat-alert/`
- [x] Symlinks created in `/usr/local/bin/`
- [x] Configuration file created with Telegram credentials
- [x] Feed directories created
- [x] Initial feed download successful (387 IPs from Emerging Threats)
- [x] Cron jobs scheduled (12-hour feed update, 5-minute anomaly detection)
- [x] Telegram test alert sent successfully
- [x] `security_monitor.sh --check` working
- [x] Logs directory created with proper permissions
- [x] Scripts are POSIX/ash compatible
- [x] System doesn't interfere with existing services

---

## 🎓 Educational Notes

This MVP demonstrates:
- Lightweight threat detection on resource-constrained routers
- POSIX shell scripting for OpenWrt compatibility
- Graceful degradation (works with partial feeds)
- Real-time monitoring without external dependencies
- Integration with existing services (AdGuardHome, Telegram)

The system is designed to be:
- **Simple:** No dependencies beyond curl and standard utilities
- **Fast:** Minimal CPU/RAM usage
- **Reliable:** Continues operating even if some feeds fail
- **Observable:** Comprehensive logging and real-time dashboard

---

**Installation completed successfully on 2026-04-14 at 21:04 UTC**
