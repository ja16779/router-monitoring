# OpenWrt Threat Alert System - Development Roadmap

## 📊 Current Status: MVP (Phase 1)

### Phase 1 ✅ COMPLETE - Threat Intelligence & Detection

**Completed:**
- [x] Threat feed downloader (URLhaus, Emerging Threats)
- [x] AdGuardHome integration
- [x] Port scanning detection
- [x] SSH brute force detection
- [x] DNS flooding detection
- [x] Telegram notifications
- [x] Logging system
- [x] Installation script
- [x] Configuration template
- [x] Documentation (README)

**Status:** Production-ready for testing. Ready for community feedback.

---

## 🚧 Phase 2 (Q2-Q3 2026) - Device Isolation & LuCI UI

### Device Isolation (Quarantine VLAN)
```
When threat detected:
├─ Identify source IP/device
├─ Move device to quarantine VLAN (192.168.99.x)
├─ Block inter-VLAN routing
├─ Allow only router access for remediation
├─ Notify admin with device info
└─ Auto-recovery timer (24h default)
```

**Tasks:**
- [ ] Implement VLAN isolation script
- [ ] Add device identification (hostname, MAC, model)
- [ ] Create auto-recovery mechanism
- [ ] Document recovery procedures

### LuCI Dashboard
```
/cgi-bin/luci/admin/services/threat-alert/

├─ Status Overview
│  ├─ Feeds (last updated, count)
│  ├─ Alerts (today, this week)
│  └─ Anomalies detected
│
├─ Configuration
│  ├─ Feed sources
│  ├─ Detection thresholds
│  └─ Alert settings
│
├─ Logs Viewer
│  ├─ Recent alerts
│  ├─ Feed updates
│  └─ Anomalies
│
└─ Device Management
   ├─ Quarantined devices
   ├─ Detection history
   └─ Manual isolation
```

**Tasks:**
- [ ] Create LuCI application skeleton
- [ ] Build status dashboard
- [ ] Configuration UI
- [ ] Logs viewer

---

## 🔬 Phase 3 (Q3-Q4 2026) - Advanced Detection

### Machine Learning Detection
- [ ] Baseline traffic profiling per device
- [ ] Behavioral anomaly detection
- [ ] Encrypted traffic analysis (size patterns)
- [ ] Time-based pattern recognition
- [ ] Auto-tuning detection thresholds

### CrowdSec Integration
```
├─ Install crowdsec-openwrt
├─ Use community blocklists
├─ Report local threats back
├─ Automated response actions
└─ Bouncer for firewall rules
```

**Tasks:**
- [ ] CrowdSec communication module
- [ ] Bouncer integration
- [ ] Local detection sharing

### Additional Feed Sources
- [ ] Shadowserver (more C2 IPs)
- [ ] OSINT feeds (custom sources)
- [ ] Private feeds (optional commercial)
- [ ] User-contributed blocklists

**Tasks:**
- [ ] Feed abstraction layer
- [ ] Support multiple formats (JSON, CSV, plaintext)
- [ ] Feed source validation

---

## 📱 Phase 4 (Q4 2026+) - Mobile & Community

### Notification Channels
- [ ] Discord webhooks
- [ ] Matrix/Element rooms
- [ ] MQTT publishing
- [ ] Email alerts
- [ ] Android push notifications

### Community Threat Database
```
├─ Submit detected threats
├─ Map ISP blocking patterns
├─ Share device/network signatures
├─ Curated threat intelligence
└─ Public statistics dashboard
```

**Tasks:**
- [ ] Community backend (API)
- [ ] Data anonymization
- [ ] Threat aggregation
- [ ] Public dashboard

### Multi-Router Coordination
- [ ] Central monitoring dashboard
- [ ] Threat correlation across multiple routers
- [ ] Shared threat intelligence
- [ ] Coordinated response actions

**Tasks:**
- [ ] Central server architecture
- [ ] Router-to-server communication
- [ ] Threat correlation engine

---

## 🎯 Priority Features (Next 30 Days)

### High Priority
1. **Test on multiple routers** (GL-MT6000, GL-MT3000, generic x86)
2. **Community feedback** (GitHub issues)
3. **Feed reliability** (handle download failures)
4. **Documentation** (installation guide, troubleshooting)

### Medium Priority
1. **VLAN isolation script** (Phase 2 start)
2. **LuCI basic dashboard** (status only)
3. **Additional feeds** (Shadow server, custom sources)

### Low Priority
1. ML detection (requires more data)
2. CrowdSec integration (nice-to-have)
3. Mobile app (future vision)

---

## 🔧 Technical Improvements

### Code Quality
- [ ] Unit tests for detection algorithms
- [ ] Integration tests (docker OpenWrt)
- [ ] Code review checklist
- [ ] Performance profiling
- [ ] Memory optimization

### Compatibility
- [ ] Test on OpenWrt 21.02, 22.03, 23.05, 25.12
- [ ] Support older devices (512MB RAM)
- [ ] ARM64, ARM32, x86_64, MIPS support
- [ ] Minimal dependency footprint

### Documentation
- [ ] Architecture diagrams
- [ ] Developer guide
- [ ] API documentation (for future extensions)
- [ ] Feed format specifications
- [ ] Troubleshooting guide (expanded)

---

## 📈 Metrics to Track

### Adoption
- GitHub stars
- Monthly active users
- Devices protected

### Effectiveness
- Malware blocks per day
- Attack detections per week
- False positive rate
- Feed freshness

### Performance
- CPU usage
- Memory footprint
- Feed update time
- Detection latency

---

## 🤝 Contributing

### For Developers
```
Areas needing help:
├─ Feed source integration
├─ Detection algorithm improvements
├─ Platform compatibility testing
├─ LuCI UI development
└─ Documentation & guides
```

### For Testers
```
What we need:
├─ Real-world testing reports
├─ Performance metrics
├─ False positive feedback
├─ Edge case discoveries
└─ Device compatibility reports
```

### For Community
```
How you can help:
├─ Share ISP blocking patterns
├─ Contribute threat intel
├─ Report bugs & ideas
├─ Translate documentation
└─ Share your use cases
```

---

## 🚀 Launch Timeline

| Date | Milestone | Status |
|------|-----------|--------|
| 2026-04-14 | MVP Release v1.0 | ✅ |
| 2026-05-15 | v1.1: Bug fixes + feedback | 🚧 |
| 2026-06-15 | v1.2: VLAN isolation | 🚧 |
| 2026-07-15 | v2.0: LuCI dashboard | 📋 |
| 2026-09-15 | v2.5: ML detection | 📋 |
| 2026-12-15 | v3.0: Community database | 📋 |

---

## 📞 Feedback Welcome!

This is a community project. Your input shapes the roadmap:

- **Feature requests:** GitHub Discussions
- **Bug reports:** GitHub Issues
- **Ideas & feedback:** Discussions tab
- **Testing:** Help with compatibility

**Let's make OpenWrt routers smarter! 🛡️**
