"""
netdoc-ai :: Configuration
All settings read from environment variables or .env file.
No hardcoded secrets. Designed for air-gapped Citi-safe operation.
"""
import os
from pathlib import Path
from typing import List

BASE_DIR = Path(__file__).parent.parent

# ── Ollama ──────────────────────────────────────────────────────────────────
OLLAMA_HOST      = os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434")
OLLAMA_MODEL     = os.getenv("OLLAMA_MODEL", "mistral:7b")
OLLAMA_TIMEOUT   = int(os.getenv("OLLAMA_TIMEOUT", "300"))   # seconds
OLLAMA_CONTEXT   = int(os.getenv("OLLAMA_CONTEXT", "8192"))  # token context window

# ── SSH / Jump-host ─────────────────────────────────────────────────────────
JUMP_HOST        = os.getenv("JUMP_HOST", "")            # e.g. 10.0.0.1
JUMP_PORT        = int(os.getenv("JUMP_PORT", "22"))
JUMP_USER        = os.getenv("JUMP_USER", "")
JUMP_KEY_PATH    = os.getenv("JUMP_KEY_PATH", "")        # path to private key
JUMP_PASSWORD    = os.getenv("JUMP_PASSWORD", "")        # fallback (key preferred)
SSH_TIMEOUT      = int(os.getenv("SSH_TIMEOUT", "30"))
SSH_BANNER_TIMEOUT = int(os.getenv("SSH_BANNER_TIMEOUT", "15"))
SSH_KNOWN_HOSTS  = os.getenv("SSH_KNOWN_HOSTS", str(BASE_DIR / "data" / "known_hosts"))

# ── Router targets ──────────────────────────────────────────────────────────
ROUTER_PORT      = int(os.getenv("ROUTER_PORT", "22"))
ROUTER_USER      = os.getenv("ROUTER_USER", "")
ROUTER_KEY_PATH  = os.getenv("ROUTER_KEY_PATH", "")
ROUTER_PASSWORD  = os.getenv("ROUTER_PASSWORD", "")
ROUTER_ENABLE_PW = os.getenv("ROUTER_ENABLE_PW", "")    # Cisco enable password
CMD_TIMEOUT      = int(os.getenv("CMD_TIMEOUT", "60"))   # per-command timeout

# ── Security / RBAC ─────────────────────────────────────────────────────────
API_KEY          = os.getenv("API_KEY", "changeme-local-poc")  # header: X-API-Key
ALLOWED_ROLES    = ["netops", "architect", "readonly", "admin"]
# Comma-separated list of IPs allowed to call the API (empty = localhost only)
ALLOWED_IPS      = [x.strip() for x in os.getenv("ALLOWED_IPS", "127.0.0.1").split(",")]

# ── Paths ────────────────────────────────────────────────────────────────────
LOG_DIR          = BASE_DIR / "logs"
REPORT_DIR       = BASE_DIR / "reports"
SESSION_DIR      = BASE_DIR / "data" / "sessions"
KB_DIR           = BASE_DIR / "knowledge_base"

# ── Regex patterns for secret sanitisation ──────────────────────────────────
SECRET_PATTERNS: List[str] = [
    r"(?i)(password|passwd|secret|key|token|enable)\s+\S+",
    r"(?i)(username\s+\S+\s+password\s+)\S+",
    r"\$\d+\$[A-Za-z0-9+/=]+",   # Cisco type-5 / type-7 hashes
    r"(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?=/\d{1,2})\s*(?=!|#|;)",  # mgmt IPs in comments
]

# ── Read-only Cisco commands (safe inventory set) ───────────────────────────
SAFE_COMMANDS: List[dict] = [
    {"cmd": "terminal length 0",        "label": "_setup",      "store": False},
    {"cmd": "show version",             "label": "version",     "store": True},
    {"cmd": "show running-config",      "label": "running_cfg", "store": True},
    {"cmd": "show ip interface brief",  "label": "ip_int_brief","store": True},
    {"cmd": "show interfaces",          "label": "interfaces",  "store": True},
    {"cmd": "show ip route",            "label": "ip_route",    "store": True},
    {"cmd": "show ip bgp summary",      "label": "bgp_summary", "store": True},
    {"cmd": "show ip ospf neighbor",    "label": "ospf_nbr",    "store": True},
    {"cmd": "show vlan brief",          "label": "vlan_brief",  "store": True},
    {"cmd": "show vrf",                 "label": "vrf",         "store": True},
    {"cmd": "show ip vrf",              "label": "ip_vrf",      "store": True},
    {"cmd": "show cdp neighbors detail","label": "cdp_nbr",     "store": True},
    {"cmd": "show spanning-tree summary","label": "stp",        "store": True},
    {"cmd": "show etherchannel summary","label": "portchannel", "store": True},
    {"cmd": "show standby brief",       "label": "hsrp",        "store": True},
    {"cmd": "show ip nat translations", "label": "nat",         "store": True},
    {"cmd": "show access-lists",        "label": "acl",         "store": True},
    {"cmd": "show crypto isakmp sa",    "label": "ipsec_ike",   "store": True},
    {"cmd": "show logging",             "label": "syslog",      "store": True},
    {"cmd": "show ntp status",          "label": "ntp",         "store": True},
    {"cmd": "show environment all",     "label": "environment", "store": True},
]
