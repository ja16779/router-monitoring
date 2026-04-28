"""
netdoc-ai :: Audit Logger
Structured JSON log for every SSH session and LLM generation.
Suitable for SIEM ingestion / Citi audit requirements.
"""
import json
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

from backend.config import LOG_DIR

LOG_DIR.mkdir(parents=True, exist_ok=True)

# ── Structured JSON log handler ──────────────────────────────────────────────
class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        obj: Dict[str, Any] = {
            "ts":      datetime.now(timezone.utc).isoformat(),
            "level":   record.levelname,
            "logger":  record.name,
            "msg":     record.getMessage(),
        }
        if hasattr(record, "extra"):
            obj.update(record.extra)
        if record.exc_info:
            obj["exc"] = self.formatException(record.exc_info)
        return json.dumps(obj)


def _build_logger(name: str, filename: str) -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)

    # File handler — JSON lines
    fh = logging.FileHandler(LOG_DIR / filename, encoding="utf-8")
    fh.setFormatter(JsonFormatter())
    fh.setLevel(logging.DEBUG)

    # Console handler — human-readable
    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(logging.Formatter(
        "%(asctime)s [%(levelname)s] %(name)s :: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    ))
    ch.setLevel(logging.INFO)

    if not logger.handlers:
        logger.addHandler(fh)
        logger.addHandler(ch)

    return logger


app_log   = _build_logger("netdoc.app",   "app.log")
audit_log = _build_logger("netdoc.audit", "audit.log")
ssh_log   = _build_logger("netdoc.ssh",   "ssh.log")
llm_log   = _build_logger("netdoc.llm",   "llm.log")


# ── Convenience audit helpers ────────────────────────────────────────────────
def log_request(session_id: str, caller_ip: str, role: str, router: str) -> None:
    audit_log.info("DOC_REQUEST", extra={
        "extra": {
            "session_id": session_id,
            "caller_ip":  caller_ip,
            "role":       role,
            "router":     router,
            "event":      "request_received",
        }
    })


def log_ssh_connect(session_id: str, router: str, success: bool,
                    error: Optional[str] = None) -> None:
    ssh_log.info("SSH_CONNECT" if success else "SSH_FAIL", extra={
        "extra": {
            "session_id": session_id,
            "router":     router,
            "success":    success,
            "error":      error,
            "event":      "ssh_connect",
        }
    })


def log_command(session_id: str, router: str, label: str,
                duration_ms: int, error: Optional[str] = None) -> None:
    ssh_log.debug("CMD_EXEC", extra={
        "extra": {
            "session_id":   session_id,
            "router":       router,
            "label":        label,
            "duration_ms":  duration_ms,
            "error":        error,
            "event":        "command_executed",
        }
    })


def log_llm_call(session_id: str, model: str, prompt_tokens: int,
                 duration_sec: float, success: bool) -> None:
    llm_log.info("LLM_CALL", extra={
        "extra": {
            "session_id":    session_id,
            "model":         model,
            "prompt_tokens": prompt_tokens,
            "duration_sec":  duration_sec,
            "success":       success,
            "event":         "llm_generate",
        }
    })


def log_report_generated(session_id: str, router: str,
                          html_path: str, pdf_path: Optional[str]) -> None:
    audit_log.info("REPORT_GEN", extra={
        "extra": {
            "session_id": session_id,
            "router":     router,
            "html":       html_path,
            "pdf":        pdf_path,
            "event":      "report_generated",
        }
    })
