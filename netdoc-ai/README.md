# NetDocAI — Air-Gapped Network Design Document Generator

> **Citi-Safe POC** · Fully offline after initial install · No data leaves the machine

---

## Overview

NetDocAI is an air-gapped, LLM-powered application that:

1. **SSHes** to a target router via an approved jump host (read-only, no config changes)
2. **Collects** safe inventory commands (`show running-config`, `show ip bgp summary`, etc.)
3. **Sanitizes** all secrets (passwords, keys, community strings) before any processing
4. **Sends** the sanitized data to a **local Ollama LLM** — nothing hits the internet
5. **Generates** a polished Network Design Document covering: hostname, platform, interfaces,
   VLANs, VRFs, routing protocols, BGP peers, ACLs, NAT, HSRP/VRRP, security posture,
   operational risks, and follow-up validations
6. **Exports** the document as both **HTML** and **PDF** with full audit logging

---

## System Requirements

| Component | Minimum         | Recommended    |
|-----------|----------------|----------------|
| OS        | Windows 10+    | Windows 11     |
| RAM       | 6 GB free      | 16 GB          |
| Disk      | 10 GB free     | 20 GB          |
| Python    | 3.10+          | 3.12           |
| Network   | SSH to target  | Jump host      |

---

## Quick Start

### 1. Install (first time, requires internet)

```bat
cd C:\path\to\netdoc-ai
scripts\install.bat
```

This will:
- Create a Python virtual environment
- Install all dependencies from `requirements.txt`
- Download and install Ollama
- Pull the `mistral:7b` model (~4.1 GB)

### 2. Configure

```bat
copy .env.example .env
notepad .env
```

Fill in your jump host and router credentials:

```env
JUMP_HOST=10.0.0.1
JUMP_USER=netops
JUMP_KEY_PATH=C:/Users/ja167/.ssh/jump_id_rsa

ROUTER_USER=readonly
ROUTER_KEY_PATH=C:/Users/ja167/.ssh/router_id_rsa
ROUTER_ENABLE_PW=MyEnablePassword
```

### 3. Start

```bat
scripts\start.bat
```

Open your browser: **http://localhost:8080**

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    WORKSTATION (localhost)                   │
│                                                             │
│  Browser → FastAPI (port 8080) → SSH Client → Jump Host    │
│                    ↓                              ↓         │
│              Sanitizer                        Router        │
│                    ↓                                        │
│           Ollama API (port 11434)                           │
│           mistral:7b (local, offline)                       │
│                    ↓                                        │
│         HTML/PDF Report → logs/ + reports/                  │
└─────────────────────────────────────────────────────────────┘
       ⚠ No external connections after initial setup ⚠
```

---

## Folder Structure

```
netdoc-ai/
├── backend/
│   ├── main.py               # FastAPI application + all routes
│   ├── config.py             # All settings (env vars / .env)
│   ├── models.py             # Pydantic request/response models
│   ├── ssh_client.py         # Paramiko SSH + jump-host + command collection
│   ├── sanitizer.py          # Secret redaction (20+ regex patterns)
│   ├── ollama_client.py      # Ollama API + knowledge-base injection
│   ├── report_generator.py   # HTML + PDF report generation
│   ├── auth.py               # RBAC + API key + IP allowlist
│   └── audit_logger.py       # Structured JSON audit logs
│
├── frontend/
│   ├── index.html            # Single-page application
│   ├── css/style.css         # Dark-theme Citi-styled UI
│   └── js/app.js             # Async fetch + streaming + tabs + download
│
├── knowledge_base/
│   ├── cisco_ios_reference.md      # Platform IDs, interface codes, risk table
│   ├── bgp_ospf_reference.md       # BGP states, OSPF states, route codes
│   ├── security_posture.md         # CIS benchmark, AAA, IPsec, SNMP risks
│   └── prompt_templates/
│       └── network_doc_template.md # 12-section document structure
│
├── logs/
│   ├── app.log               # Application log (INFO+)
│   ├── audit.log             # Audit log (every request + report)
│   ├── ssh.log               # SSH session + command log
│   └── llm.log               # LLM call timing + token estimates
│
├── reports/                  # Generated HTML + PDF reports (named by session)
├── data/sessions/            # Session JSON records for history panel
│
├── scripts/
│   ├── install.bat           # Windows installer
│   ├── start.bat             # Windows launcher
│   ├── setup_ollama.sh       # Linux/macOS Ollama setup
│   └── health_check.sh       # Quick status check
│
├── .env.example              # Configuration template
├── requirements.txt          # Python dependencies
└── README.md                 # This file
```

---

## API Reference

All endpoints are documented at: **http://localhost:8080/api/docs**

| Method | Endpoint                 | Auth     | Description                      |
|--------|--------------------------|----------|----------------------------------|
| GET    | `/api/health`            | None     | System health check              |
| GET    | `/api/models`            | API Key  | List installed Ollama models     |
| POST   | `/api/generate`          | API Key + Role | Full document generation  |
| POST   | `/api/generate/stream`   | API Key + Role | Streaming generation (SSE)|
| GET    | `/api/reports/{file}`    | API Key  | Download HTML/PDF report         |
| GET    | `/api/sessions`          | API Key + Role | Session history             |

### Authentication Headers

```http
X-API-Key: changeme-local-poc
X-User-Role: architect
```

---

## RBAC Roles

| Role       | Generate | History | Health | Notes                    |
|------------|----------|---------|--------|--------------------------|
| `admin`    | ✓        | ✓       | ✓      | Full access              |
| `netops`   | ✓        | ✓       | ✓      | Operations team          |
| `architect`| ✓        | ✓       | ✓      | Design/architecture team |
| `readonly` | ✗        | ✓       | ✓      | View history only        |

---

## Safe Command Set

NetDocAI only issues read-only commands. No `configure terminal`, no `write`, no `clear`.

The approved command list is defined in `backend/config.py → SAFE_COMMANDS`:

| Command                       | Purpose                    |
|-------------------------------|----------------------------|
| `show version`                | Platform / IOS version     |
| `show running-config`         | Full config (sanitized)    |
| `show ip interface brief`     | Interface status summary   |
| `show interfaces`             | Detailed interface stats   |
| `show ip route`               | Routing table              |
| `show ip bgp summary`         | BGP neighbor table         |
| `show ip ospf neighbor`       | OSPF neighbor state        |
| `show vlan brief`             | VLAN table                 |
| `show vrf` / `show ip vrf`    | VRF configuration          |
| `show cdp neighbors detail`   | L2 topology discovery      |
| `show spanning-tree summary`  | STP root / state           |
| `show etherchannel summary`   | Port-channel / LAG         |
| `show standby brief`          | HSRP groups                |
| `show ip nat translations`    | NAT table                  |
| `show access-lists`           | ACL rules                  |
| `show crypto isakmp sa`       | IPsec IKE sessions         |
| `show logging`                | Syslog buffer              |
| `show ntp status`             | NTP synchronization        |
| `show environment all`        | Hardware sensors           |

---

## Secret Sanitization

Before any data reaches the LLM, the following patterns are redacted:

- `enable secret / password X` → `enable secret [REDACTED]`
- `username X password X` → `username X password [REDACTED]`
- `snmp-server community X` → `snmp-server community [REDACTED]`
- `neighbor X password X` → `neighbor X password [REDACTED]`
- `pre-shared-key X` → `pre-shared-key [REDACTED]`
- Cisco type-5 (`$1$...`) and type-6 (`$6$...`) password hashes
- TACACS+/RADIUS server keys
- BGP MD5 authentication keys
- OSPF message-digest keys
- PEM private key blocks

---

## Choosing a Model

With 7.4 GB RAM:

| Model           | Size  | Fit    | Quality         | Recommended for          |
|-----------------|-------|--------|-----------------|--------------------------|
| `mistral:7b`    | 4.1 GB| ✓ Best | Excellent        | **Default — use this**   |
| `llama3.2:3b`   | 2.0 GB| ✓✓     | Good             | Low-RAM fallback         |
| `phi3.5:mini`   | 2.3 GB| ✓✓     | Good             | Fast, lighter            |
| `llama3.1:8b`   | 4.7 GB| ⚠ Tight| Best quality     | If 16+ GB RAM available  |
| `codellama:13b` | 7.4 GB| ✗ OOM  | N/A              | Needs 16 GB+             |

To switch model:
```env
# In .env:
OLLAMA_MODEL=llama3.2:3b
```
Then: `ollama pull llama3.2:3b`

---

## Offline Operation

After initial installation, NetDocAI requires **zero internet access**:

- Ollama runs entirely on CPU/GPU locally
- Model weights stored in `C:\Users\<user>\.ollama\models\`
- No telemetry, no cloud API calls, no external DNS lookups during operation
- All reports stored locally in `reports/`
- All logs stored locally in `logs/`

---

## Security Notes

1. **API Key**: Change `API_KEY` in `.env` before any networked deployment
2. **IP Allowlist**: Set `ALLOWED_IPS=127.0.0.1` for localhost-only (default)
3. **SSH Keys**: Use key-based auth; avoid passwords in `.env` where possible
4. **Logs**: `audit.log` records every request (IP, role, router, timestamp)
5. **Reports**: HTML/PDF contain sanitized data only — safe to share internally
6. **LDAP/AD**: See extension point in `backend/auth.py` for Citi AD integration

---

## PDF Support

```bat
pip install weasyprint
```

WeasyPrint requires GTK on Windows. Alternatively:
- Print the HTML report to PDF from the browser (Ctrl+P → Save as PDF)

---

## Extending the Knowledge Base

Add `.md` or `.json` files to `knowledge_base/` — they are automatically
injected into every LLM prompt at runtime. No model retraining needed.

Examples:
- `knowledge_base/nxos_reference.md` — NX-OS specific patterns
- `knowledge_base/mpls_reference.md` — MPLS/LDP/RSVP documentation
- `knowledge_base/prompt_templates/bgp_focused.md` — BGP-only deep-dive template

---

## Troubleshooting

| Problem                        | Solution                                      |
|--------------------------------|-----------------------------------------------|
| "Ollama offline" in UI         | Run `ollama serve` or `scripts\start.bat`    |
| "SSH connection failed"        | Check `.env` credentials + jump host reachable|
| "No data" from router          | Router may require `terminal length 0` first |
| Generation very slow           | Normal for first run; subsequent calls faster |
| Out of memory during LLM       | Switch to `llama3.2:3b` in `.env`           |
| PDF not generated              | `pip install weasyprint` or use HTML report  |
| RBAC denied                    | Check `X-User-Role` header matches role      |

---

*NetDocAI v1.0 — Citi Internal POC — All data processed locally — No external dependencies during operation*
