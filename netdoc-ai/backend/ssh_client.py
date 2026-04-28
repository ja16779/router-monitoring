"""
netdoc-ai :: SSH Client
Read-only SSH automation via paramiko.
Supports:
  - Direct SSH to router
  - SSH via jump-host (ProxyJump)
  - Cisco IOS enable mode
All commands are drawn from the pre-approved SAFE_COMMANDS list.
No write commands are issued.
"""
import time
import uuid
from datetime import datetime
from typing import List, Optional

import paramiko

from backend.config import (
    CMD_TIMEOUT,
    JUMP_HOST,
    JUMP_KEY_PATH,
    JUMP_PASSWORD,
    JUMP_PORT,
    JUMP_USER,
    ROUTER_ENABLE_PW,
    ROUTER_KEY_PATH,
    ROUTER_PASSWORD,
    ROUTER_PORT,
    ROUTER_USER,
    SAFE_COMMANDS,
    SSH_BANNER_TIMEOUT,
    SSH_TIMEOUT,
)
from backend.models import CommandOutput, SSHResult
from backend.sanitizer import sanitize
from backend.audit_logger import log_ssh_connect, log_command, ssh_log


# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_client() -> paramiko.SSHClient:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.WarningPolicy())
    return client


def _auth_kwargs(key_path: str, password: str) -> dict:
    """Build paramiko auth kwargs preferring key over password."""
    kwargs: dict = {"timeout": SSH_TIMEOUT, "banner_timeout": SSH_BANNER_TIMEOUT,
                    "auth_timeout": SSH_TIMEOUT}
    if key_path:
        try:
            kwargs["pkey"] = paramiko.RSAKey.from_private_key_file(key_path)
        except Exception:
            try:
                kwargs["pkey"] = paramiko.Ed25519Key.from_private_key_file(key_path)
            except Exception:
                pass
    if "pkey" not in kwargs and password:
        kwargs["password"] = password
    elif "pkey" not in kwargs:
        kwargs["password"] = password  # will fail gracefully
    return kwargs


def _read_until_prompt(shell: paramiko.Channel,
                        timeout: float = 30.0) -> str:
    """
    Read from an interactive Cisco shell until we see a prompt indicator
    (# or >). Returns accumulated output.
    """
    buf   = ""
    start = time.monotonic()
    shell.settimeout(2.0)

    while (time.monotonic() - start) < timeout:
        try:
            chunk = shell.recv(4096).decode("utf-8", errors="replace")
            buf  += chunk
            # Cisco prompts end with  #  or  >  or  (config)#
            stripped = buf.rstrip()
            if stripped.endswith("#") or stripped.endswith(">"):
                break
        except Exception:
            # recv timeout — still waiting
            if buf and (buf.rstrip().endswith("#") or buf.rstrip().endswith(">")):
                break
    return buf


def _send_cmd(shell: paramiko.Channel, cmd: str,
              timeout: float = CMD_TIMEOUT) -> str:
    shell.send(cmd + "\n")
    time.sleep(0.3)
    output = _read_until_prompt(shell, timeout=timeout)
    # Strip the echoed command from the beginning
    lines = output.splitlines()
    if lines and cmd.strip() in lines[0]:
        lines = lines[1:]
    return "\n".join(lines)


# ── Core collector ────────────────────────────────────────────────────────────

def collect_router_data(
    session_id: str,
    router_name: str,
    router_ip: str,
    override_commands: Optional[List[str]] = None,
) -> SSHResult:
    """
    SSH to the router (directly or via jump host) and run the safe command set.
    Returns SSHResult with sanitised outputs.
    """
    ssh_log.info(f"[{session_id}] Starting collection for {router_name} ({router_ip})")

    result = SSHResult(
        router_name=router_name,
        router_ip=router_ip,
        connected=False,
    )

    # ── Determine which commands to run ──────────────────────────────────────
    if override_commands:
        # Validate against safe list
        safe_set = {c["cmd"].strip().lower() for c in SAFE_COMMANDS}
        commands = [
            c for c in override_commands
            if c.strip().lower() in safe_set
        ]
        if len(commands) != len(override_commands):
            ssh_log.warning(f"[{session_id}] Some override commands rejected (not in safe list)")
    else:
        commands = None  # use full SAFE_COMMANDS

    command_plan = commands or [c for c in SAFE_COMMANDS]

    try:
        # ── Open transport ────────────────────────────────────────────────────
        if JUMP_HOST:
            ssh_log.info(f"[{session_id}] Connecting via jump host {JUMP_HOST}")
            jump_client = _make_client()
            jump_client.connect(
                hostname=JUMP_HOST,
                port=JUMP_PORT,
                username=JUMP_USER,
                **_auth_kwargs(JUMP_KEY_PATH, JUMP_PASSWORD),
            )
            transport   = jump_client.get_transport()
            dest_addr   = (router_ip, ROUTER_PORT)
            src_addr    = (JUMP_HOST, 0)
            channel     = transport.open_channel("direct-tcpip", dest_addr, src_addr)

            router_client = _make_client()
            router_client.connect(
                hostname=router_ip,
                port=ROUTER_PORT,
                username=ROUTER_USER,
                sock=channel,
                **_auth_kwargs(ROUTER_KEY_PATH, ROUTER_PASSWORD),
            )
        else:
            ssh_log.info(f"[{session_id}] Direct connect to {router_ip}:{ROUTER_PORT}")
            router_client = _make_client()
            router_client.connect(
                hostname=router_ip,
                port=ROUTER_PORT,
                username=ROUTER_USER,
                **_auth_kwargs(ROUTER_KEY_PATH, ROUTER_PASSWORD),
            )

        result.connected = True
        log_ssh_connect(session_id, router_name, True)

        # ── Open interactive shell ────────────────────────────────────────────
        shell = router_client.invoke_shell(term="vt100", width=200, height=50)
        time.sleep(1.5)
        shell.recv(65535)  # discard banner

        # Disable paging
        _send_cmd(shell, "terminal length 0", timeout=10)
        _send_cmd(shell, "terminal width 200", timeout=10)

        # Enter enable mode if password configured
        if ROUTER_ENABLE_PW:
            out = _send_cmd(shell, "enable", timeout=10)
            if "Password" in out or "password" in out:
                _send_cmd(shell, ROUTER_ENABLE_PW, timeout=10)

        # ── Execute commands ──────────────────────────────────────────────────
        for entry in (command_plan if isinstance(command_plan[0], dict)
                      else [{"cmd": c, "label": c, "store": True}
                            for c in command_plan]):
            cmd   = entry["cmd"]
            label = entry["label"]
            store = entry.get("store", True)

            t0 = time.monotonic()
            try:
                raw_output = _send_cmd(shell, cmd, timeout=CMD_TIMEOUT)
                duration   = int((time.monotonic() - t0) * 1000)

                if store:
                    cleaned = sanitize(raw_output)
                    result.outputs.append(CommandOutput(
                        label=label,
                        command=cmd,
                        output=cleaned,
                        sanitized=True,
                        duration_ms=duration,
                    ))
                log_command(session_id, router_name, label, duration)

            except Exception as e:
                duration = int((time.monotonic() - t0) * 1000)
                ssh_log.warning(f"[{session_id}] Command '{cmd}' failed: {e}")
                log_command(session_id, router_name, label, duration, error=str(e))
                result.outputs.append(CommandOutput(
                    label=label,
                    command=cmd,
                    output="",
                    error=str(e),
                    duration_ms=duration,
                ))

        router_client.close()
        if JUMP_HOST:
            jump_client.close()

    except Exception as e:
        ssh_log.error(f"[{session_id}] SSH connection failed: {e}")
        log_ssh_connect(session_id, router_name, False, error=str(e))
        result.error = str(e)

    result.collected_at = datetime.utcnow()
    return result
