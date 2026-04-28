# Contributing to OpenWrt Threat Alert System

Thank you for your interest in contributing! This document provides guidelines for participation.

## 🎯 How to Contribute

### 1. Report Bugs

**Found a bug?**
1. Check existing issues first (might already be reported)
2. Create a new issue with:
   - Clear title and description
   - OpenWrt version (`cat /etc/openwrt_release`)
   - Router model
   - Steps to reproduce
   - Expected vs actual behavior
   - Relevant log excerpts

**Example:**
```
Title: Feed updater fails on GL-MT3000

OpenWrt: 25.12.2
Router: GL-MT3000 (Beryl)
Issue: threat_feed_updater.sh exits with "curl: command not found"
Expected: Feed downloads and updates
Steps: Run /usr/local/bin/threat_feed_updater.sh
Logs: [paste log output]
```

### 2. Suggest Features

**Have an idea?**
1. Check discussions/issues (might exist)
2. Open a discussion or feature request with:
   - Use case description
   - Why it's needed
   - Proposed approach (optional)
   - References/links (optional)

**Example:**
```
Title: Device quarantine in VLAN

Use case: When botnet detected on IoT device, auto-isolate it
Why needed: Prevent lateral movement to other devices
Approach: Move device to 192.168.99.x VLAN, block inter-VLAN routing
Rough implementation: [describe]
```

### 3. Submit Code

**Contributing code?**

#### Step 1: Fork & Clone
```bash
git clone https://github.com/yourusername/threat-alert-openwrt.git
cd threat-alert-openwrt
git checkout -b feature/my-feature
```

#### Step 2: Make Changes
```bash
# Follow existing code style
# Add comments for complex logic
# Test locally on actual OpenWrt router
```

#### Step 3: Test
```bash
# Run on your router
ssh root@192.168.10.1 < install.sh

# Manual testing
/usr/local/bin/threat_feed_updater.sh
/usr/local/bin/anomaly_detector.sh

# Check logs
tail -20 /var/log/threat-alert/*.log
```

#### Step 4: Commit & Push
```bash
git add .
git commit -m "Add: feature description (clear, concise)"
git push origin feature/my-feature
```

#### Step 5: Create Pull Request
- Link any related issues
- Describe changes clearly
- Explain testing done
- Include any breaking changes

**PR Title Format:**
```
[type]: Short description

Examples:
- [Feature] Add VLAN isolation support
- [Fix] Prevent feed update timeout on slow connections
- [Docs] Update installation guide for GL-MT3000
- [Test] Add unit tests for anomaly detector
```

---

## 🛠️ Development Setup

### Local Development (with Docker)

```bash
# Build OpenWrt environment
docker run -it openwrt/openwrt:latest

# Inside container:
cd /tmp
git clone https://github.com/yourusername/threat-alert-openwrt.git
cd threat-alert-openwrt
./install.sh

# Test
/usr/local/bin/threat_feed_updater.sh
```

### Testing on Real Router

```bash
# Copy to router
scp -r . root@192.168.10.1:/tmp/test/

# SSH and test
ssh root@192.168.10.1
cd /tmp/test
./install.sh
```

---

## 📋 Code Standards

### Shell Script Style

```bash
#!/bin/sh
# Clear file header with purpose

# Configuration and setup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

# Logging functions
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1"
}

# Main functions with clear names
process_feed() {
    local feed_url="$1"
    local output_file="$2"

    # Add comments for complex logic
    # ...
}

# Main execution
main() {
    # Call functions
}

main "$@"
```

### Key Guidelines

1. **Portability:** Use POSIX-compatible shell (`#!/bin/sh`, not bash)
2. **Error handling:** Check return codes, use `set -e` for critical sections
3. **Quoting:** Quote variables: `"$VAR"` not `$VAR`
4. **Functions:** Use lowercase with underscores: `update_feeds`, not `updateFeeds`
5. **Comments:** Explain WHY, not WHAT (code shows what)
6. **Logging:** Use consistent log format with timestamps

---

## 🧪 Testing Requirements

### Before Submitting PR

- [ ] Code runs without errors on OpenWrt 25.12
- [ ] Code tested on at least one other version (21.02, 22.03, 23.05)
- [ ] No new dependencies added (or clearly documented why)
- [ ] Logs are clear and useful
- [ ] Configuration options documented
- [ ] Error messages are helpful
- [ ] Memory/CPU usage is reasonable

### Test Checklist

```bash
# Installation
./install.sh                    # Completes without errors
ls /usr/local/lib/threat-alert  # Files exist and executable
cat /etc/threat-alert/config.sh # Config created

# Functionality
/usr/local/bin/threat_feed_updater.sh  # No errors
tail /var/log/threat-alert/updater.log # Check results

# Manual anomaly detection
/usr/local/bin/anomaly_detector.sh     # No errors

# Cron integration
grep threat-alert /etc/crontabs/root   # Jobs added
```

---

## 📚 Documentation Contributions

### Adding Documentation

Good docs are contributions too!

1. **Installation guides** for specific routers
2. **Troubleshooting** sections
3. **Real-world examples** and use cases
4. **Architecture diagrams** (ASCII or SVG)
5. **Translation** to other languages

### Doc Standards

```markdown
# Clear Heading

Explain what, why, when to use.

## Prerequisites
- List requirements
- Versions needed
- Dependencies

## Steps
1. Clear numbered steps
2. Include commands
3. Expected output shown

## Troubleshooting
**Problem:** Description
**Cause:** Why it happens
**Solution:** How to fix

## References
- Links to related docs
- External resources
```

---

## 🐛 Debugging Tips

### Enable Debug Mode

```bash
vi /etc/threat-alert/config.sh
# Change:
LOG_LEVEL="DEBUG"
```

```bash
# See all debug messages
tail -f /var/log/threat-alert/*.log | grep DEBUG
```

### Manual Testing

```bash
# Test curl connectivity
curl -I https://urlhaus-api.abuse.ch/v1/urls/recent/

# Test Telegram
curl -X POST https://api.telegram.org/bot$TOKEN/getMe

# Check processes
ps aux | grep threat

# View actual cron execution
logread | grep threat-alert
```

---

## 🤝 Communication

### Discussion Channels

- **GitHub Issues:** Bug reports and feature requests
- **GitHub Discussions:** Ideas and general questions
- **PR Comments:** Code-specific feedback

### Code Review Process

1. **Automated checks** (if CI enabled)
2. **Code review** by maintainers
3. **Testing feedback** from community
4. **Revisions** as needed
5. **Merge** when approved

### Be Respectful

- Assume good intent
- Provide constructive feedback
- Help others learn
- Accept constructive criticism gracefully

---

## 📋 Commit Message Guidelines

```
[type]: Brief description (50 chars max)

Longer explanation (optional):
- Why this change was needed
- What problems it solves
- Implementation notes
- Potential edge cases

Related issues: Fixes #123, Related to #456
```

**Types:**
- `[Feature]` - New functionality
- `[Fix]` - Bug fix
- `[Improvement]` - Code quality, performance
- `[Docs]` - Documentation only
- `[Test]` - Test additions
- `[Refactor]` - Code reorganization

---

## 🏆 Contributor Recognition

Contributors are recognized in:
- README.md acknowledgments
- Release notes
- GitHub contributor graph

---

## ⚖️ License

By contributing, you agree your code is licensed under the MIT License (same as project).

---

## 💡 Ideas for First Contributions

- [ ] Test on GL-MT3000 (Beryl) router
- [ ] Create installation video/guide
- [ ] Add support for new feed source
- [ ] Write bash unit tests
- [ ] Improve error messages
- [ ] Add more threat detection method
- [ ] Create LuCI dashboard mockup
- [ ] Document real-world use cases

---

## 🙏 Thank You!

Thank you for helping make OpenWrt routers more secure! Your contributions make a difference.

**Questions?** Open an issue or discussion, we're here to help!
