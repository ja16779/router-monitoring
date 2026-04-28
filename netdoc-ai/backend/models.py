"""
netdoc-ai :: Pydantic data models
"""
from __future__ import annotations
from datetime import datetime
from enum import Enum
from typing import Dict, List, Optional
from pydantic import BaseModel, Field, field_validator
import re


class UserRole(str, Enum):
    netops    = "netops"
    architect = "architect"
    readonly  = "readonly"
    admin     = "admin"


class DocRequest(BaseModel):
    router_name: str = Field(..., min_length=1, max_length=128,
                              description="Hostname or IP of the target router")
    router_ip: Optional[str] = Field(None, description="Explicit IP (if name != IP)")
    role: UserRole = Field(UserRole.readonly, description="Caller role for RBAC")
    commands: Optional[List[str]] = Field(
        None, description="Override default command set (must be in safe list)"
    )
    extra_context: Optional[str] = Field(
        None, max_length=2000,
        description="Additional context injected into the LLM prompt"
    )
    include_pdf: bool = Field(True, description="Also generate PDF report")

    @field_validator("router_name")
    @classmethod
    def validate_hostname(cls, v: str) -> str:
        v = v.strip()
        # Allow hostnames, FQDNs, and IPv4
        pattern = r"^[a-zA-Z0-9\-\_\.]{1,128}$"
        if not re.match(pattern, v):
            raise ValueError("router_name contains invalid characters")
        # Block obvious injection attempts
        blocked = [";", "&", "|", "`", "$", "(", ")", "<", ">", "\\", "\n", "\r"]
        for ch in blocked:
            if ch in v:
                raise ValueError(f"router_name contains forbidden character: {ch!r}")
        return v

    @field_validator("router_ip")
    @classmethod
    def validate_ip(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        # Basic IPv4 validation
        parts = v.strip().split(".")
        if len(parts) != 4:
            raise ValueError("router_ip must be a valid IPv4 address")
        for part in parts:
            if not part.isdigit() or not 0 <= int(part) <= 255:
                raise ValueError("router_ip must be a valid IPv4 address")
        return v.strip()


class CommandOutput(BaseModel):
    label:     str
    command:   str
    output:    str
    sanitized: bool = True
    error:     Optional[str] = None
    duration_ms: int = 0


class SSHResult(BaseModel):
    router_name: str
    router_ip:   str
    connected:   bool
    outputs:     List[CommandOutput] = []
    error:       Optional[str] = None
    collected_at: datetime = Field(default_factory=datetime.utcnow)


class DocResponse(BaseModel):
    session_id:   str
    router_name:  str
    status:       str                    # "success" | "partial" | "error"
    document:     Optional[str] = None  # Full markdown document
    html_report:  Optional[str] = None  # Path to HTML file
    pdf_report:   Optional[str] = None  # Path to PDF file
    warnings:     List[str] = []
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    model_used:   str = ""
    duration_sec: float = 0.0


class HealthResponse(BaseModel):
    status:        str
    ollama_online: bool
    model_loaded:  Optional[str]
    version:       str = "1.0.0"
