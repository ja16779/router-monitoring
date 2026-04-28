"""
netdoc-ai :: RBAC & Auth middleware
Role-based access hooks for API endpoints.
Designed as POC-ready; plug in LDAP/AD integration at the marked extension points.
"""
from functools import wraps
from typing import Callable, List, Optional, Set

from fastapi import Depends, Header, HTTPException, Request, status

from backend.config import API_KEY, ALLOWED_IPS, ALLOWED_ROLES
from backend.audit_logger import app_log


# ── Permission matrix ─────────────────────────────────────────────────────────
#  role          → allowed actions
ROLE_PERMISSIONS: dict[str, Set[str]] = {
    "admin":     {"generate", "history", "health", "models"},
    "netops":    {"generate", "history", "health"},
    "architect": {"generate", "history", "health"},
    "readonly":  {"history",  "health"},
}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _get_caller_ip(request: Request) -> str:
    # Respect X-Forwarded-For if behind a proxy
    fwd = request.headers.get("X-Forwarded-For")
    if fwd:
        return fwd.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def verify_api_key(x_api_key: str = Header(..., alias="X-API-Key")) -> str:
    """FastAPI dependency — validates static API key."""
    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key",
            headers={"WWW-Authenticate": "ApiKey"},
        )
    return x_api_key


def verify_ip(request: Request) -> str:
    """FastAPI dependency — validates caller IP against allowlist."""
    caller = _get_caller_ip(request)
    if ALLOWED_IPS and caller not in ALLOWED_IPS:
        app_log.warning(f"Rejected request from unlisted IP: {caller}")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Access denied for IP {caller}",
        )
    return caller


def require_permission(action: str):
    """
    FastAPI dependency factory.
    Usage: Depends(require_permission("generate"))
    """
    def _dep(
        role: str = Header("readonly", alias="X-User-Role"),
        _ip:  str = Depends(verify_ip),
        _key: str = Depends(verify_api_key),
    ) -> str:
        if role not in ALLOWED_ROLES:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Unknown role: {role}",
            )
        perms = ROLE_PERMISSIONS.get(role, set())
        if action not in perms:
            app_log.warning(f"Role '{role}' attempted unauthorised action '{action}'")
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role '{role}' is not permitted to perform '{action}'",
            )
        return role

    return _dep


# ── Extension point: LDAP / Active Directory ──────────────────────────────────
# To integrate with Citi AD, replace verify_api_key with an LDAP bind:
#
# import ldap3
# def verify_ldap(credentials: HTTPBasicCredentials = Depends(HTTPBasic())):
#     server = ldap3.Server("ldaps://ad.citi.internal", use_ssl=True)
#     conn   = ldap3.Connection(server, credentials.username,
#                                credentials.password, auto_bind=True)
#     # resolve role from AD group membership
#     ...
