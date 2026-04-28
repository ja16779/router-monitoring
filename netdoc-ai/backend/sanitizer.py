"""
netdoc-ai :: Secret Sanitizer
Strips passwords, keys, and sensitive data from router output
before passing to the local LLM. Nothing leaves the machine either way,
but this enforces a defence-in-depth posture for Citi compliance.
"""
import re
from typing import List, Tuple

# ── Pattern catalogue ─────────────────────────────────────────────────────────
_RULES: List[Tuple[re.Pattern, str]] = [

    # Cisco IOS / IOS-XE / NX-OS — type 5 (MD5) and type 7 passwords
    (re.compile(r"(password\s+(?:7|5|0|encrypted)\s+)\S+", re.I),
     r"\1[REDACTED]"),

    # enable secret / enable password
    (re.compile(r"(enable\s+(?:secret|password)\s+(?:\d+\s+)?)\S+", re.I),
     r"\1[REDACTED]"),

    # username ... password / secret
    (re.compile(r"(username\s+\S+\s+(?:password|secret)\s+(?:\d+\s+)?)\S+", re.I),
     r"\1[REDACTED]"),

    # key / pre-shared-key / authentication-key
    (re.compile(r"((?:pre-shared-key|authentication-key|key\s+chain|"
                r"key-string|ntp\s+authentication-key\s+\d+\s+md5)\s+)\S+", re.I),
     r"\1[REDACTED]"),

    # SNMP community strings
    (re.compile(r"(snmp-server\s+community\s+)\S+", re.I),
     r"\1[REDACTED]"),

    # BGP neighbor passwords
    (re.compile(r"(neighbor\s+\S+\s+password\s+(?:\d+\s+)?)\S+", re.I),
     r"\1[REDACTED]"),

    # OSPF / EIGRP message-digest-key
    (re.compile(r"(message-digest-key\s+\d+\s+md5\s+(?:\d+\s+)?)\S+", re.I),
     r"\1[REDACTED]"),

    # ISIS / PPP authentication passwords
    (re.compile(r"((?:isis\s+)?authentication\s+(?:key-chain|password)\s+)\S+", re.I),
     r"\1[REDACTED]"),

    # TACACS / RADIUS server key
    (re.compile(r"((?:tacacs|radius)-server\s+(?:host\s+\S+\s+)?key\s+(?:\d+\s+)?)\S+", re.I),
     r"\1[REDACTED]"),

    # AAA secret
    (re.compile(r"(aaa\s+\S+\s+\S+\s+\S+\s+key\s+)\S+", re.I),
     r"\1[REDACTED]"),

    # Crypto ISAKMP / IKE PSK
    (re.compile(r"((?:authentication\s+pre-share|set\s+preshared-key)\s+)\S+", re.I),
     r"\1[REDACTED]"),

    # Cisco type-6 AES encrypted passwords (EEM / Flex VPN)
    (re.compile(r"\$6\$[A-Za-z0-9+/=]{20,}", re.I), "[TYPE6-REDACTED]"),
    (re.compile(r"\$5\$[A-Za-z0-9+/=]{20,}", re.I), "[TYPE5-REDACTED]"),

    # Private key material (PEM blocks)
    (re.compile(r"-----BEGIN[^\n]*PRIVATE KEY-----.*?-----END[^\n]*KEY-----",
                re.DOTALL | re.I), "[PEM-PRIVATE-KEY-REDACTED]"),

    # VPN tunnel addresses that look like RFC1918 (keep structure, not value)
    # -- intentionally NOT redacting IPs; they are needed for topology docs --
]


def sanitize(text: str, extra_patterns: List[str] | None = None) -> str:
    """
    Apply all sanitisation rules to `text`.
    Returns cleaned text with secrets replaced by [REDACTED] markers.
    """
    if extra_patterns:
        for pat in extra_patterns:
            try:
                text = re.sub(pat, "[REDACTED]", text, flags=re.I)
            except re.error:
                pass  # skip invalid caller-supplied patterns

    for pattern, replacement in _RULES:
        text = pattern.sub(replacement, text)

    return text


def sanitize_command_set(outputs: list) -> list:
    """Sanitize a list of CommandOutput dicts in place and return them."""
    for item in outputs:
        if isinstance(item, dict) and "output" in item:
            item["output"]    = sanitize(item["output"])
            item["sanitized"] = True
        elif hasattr(item, "output"):
            item.output    = sanitize(item.output)
            item.sanitized = True
    return outputs
