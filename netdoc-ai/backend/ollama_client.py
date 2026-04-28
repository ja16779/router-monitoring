"""
netdoc-ai :: Ollama Client
Calls the local Ollama REST API (http://127.0.0.1:11434) — fully offline.
Injects knowledge-base context (Cisco reference + prompt templates)
into every generation request.
"""
import json
import time
from pathlib import Path
from typing import Generator, Optional

import httpx

from backend.config import (
    KB_DIR,
    OLLAMA_CONTEXT,
    OLLAMA_HOST,
    OLLAMA_MODEL,
    OLLAMA_TIMEOUT,
)
from backend.audit_logger import llm_log, log_llm_call


# ── Knowledge-base loader ─────────────────────────────────────────────────────

def _load_kb_context() -> str:
    """
    Load all markdown/json reference files from knowledge_base/.
    Returns a single concatenated string injected as system context.
    """
    parts: list[str] = []
    for ext in ("*.md", "*.json"):
        for fp in sorted(KB_DIR.glob(ext)):
            try:
                parts.append(f"\n\n### [{fp.stem}]\n{fp.read_text(encoding='utf-8')}")
            except Exception:
                pass
    # Load prompt templates
    tmpl_dir = KB_DIR / "prompt_templates"
    if tmpl_dir.exists():
        for fp in sorted(tmpl_dir.glob("*.md")):
            try:
                parts.append(f"\n\n### [TEMPLATE:{fp.stem}]\n{fp.read_text(encoding='utf-8')}")
            except Exception:
                pass
    return "".join(parts)


_KB_CACHE: Optional[str] = None


def _get_kb() -> str:
    global _KB_CACHE
    if _KB_CACHE is None:
        _KB_CACHE = _load_kb_context()
    return _KB_CACHE


# ── System prompt ─────────────────────────────────────────────────────────────

_SYSTEM_PROMPT = """You are NetDocAI, a senior Cisco network architect and documentation specialist
embedded in an air-gapped enterprise environment. Your role is to analyze raw router
CLI output and produce a polished, accurate Network Design Document suitable for
infrastructure architects and operations teams.

Rules:
1. Be factual — extract data directly from the CLI output. Never invent IP addresses,
   interface names, or routing entries that are not present in the data.
2. Structure your output in clean Markdown with the sections defined in the template.
3. Flag missing data clearly (e.g., "BGP not configured" rather than leaving blank).
4. Identify operational risks and security posture concerns based on the config.
5. Use professional network engineering terminology.
6. Never reproduce [REDACTED] values — acknowledge they exist for security reasons.
7. All analysis is for documentation purposes only — recommend no changes without
   explicit operator instruction.
"""


# ── Prompt builder ────────────────────────────────────────────────────────────

def build_prompt(router_name: str, outputs: list,
                 extra_context: Optional[str] = None) -> str:
    """
    Build the full LLM prompt from CLI outputs + KB context.
    """
    kb = _get_kb()

    sections = []
    for out in outputs:
        if isinstance(out, dict):
            label   = out.get("label", "output")
            command = out.get("command", "")
            text    = out.get("output", "").strip()
            error   = out.get("error")
        else:
            label   = out.label
            command = out.command
            text    = out.output.strip()
            error   = out.error

        if error:
            sections.append(f"### {label} ({command})\nERROR: {error}\n")
        elif text:
            sections.append(f"### {label} ({command})\n```\n{text[:8000]}\n```\n")

    cli_block = "\n".join(sections)

    extra = f"\n\n**Additional Operator Context:**\n{extra_context}" if extra_context else ""

    prompt = f"""
{kb}

---

## Task
Analyze the following CLI output captured from router **{router_name}** and produce a
complete Network Design Document following the template structure above.

{extra}

## Router CLI Data

{cli_block}

---

## Output Instructions
Generate the full Network Design Document now in Markdown format.
Start immediately with the document title. Be thorough, structured, and precise.
""".strip()

    return prompt


# ── Ollama API calls ──────────────────────────────────────────────────────────

def health_check() -> tuple[bool, Optional[str]]:
    """Returns (is_online, model_name_if_loaded)."""
    try:
        with httpx.Client(timeout=5) as client:
            r = client.get(f"{OLLAMA_HOST}/api/tags")
            if r.status_code == 200:
                models = [m["name"] for m in r.json().get("models", [])]
                loaded = next((m for m in models if OLLAMA_MODEL in m), None)
                return True, loaded
    except Exception:
        pass
    return False, None


def generate_document(
    session_id: str,
    router_name: str,
    outputs: list,
    extra_context: Optional[str] = None,
    model: Optional[str] = None,
) -> str:
    """
    Call Ollama /api/generate (non-streaming) and return the full response text.
    Raises on failure.
    """
    model = model or OLLAMA_MODEL
    prompt = build_prompt(router_name, outputs, extra_context)
    token_estimate = len(prompt.split()) // 0.75  # rough token estimate

    llm_log.info(f"[{session_id}] Sending prompt to {model} "
                 f"(~{int(token_estimate)} tokens, {len(prompt)} chars)")

    payload = {
        "model":  model,
        "prompt": prompt,
        "system": _SYSTEM_PROMPT,
        "stream": False,
        "options": {
            "num_ctx":         OLLAMA_CONTEXT,
            "temperature":     0.15,    # low temp for factual doc generation
            "top_p":           0.9,
            "repeat_penalty":  1.1,
            "num_predict":     4096,    # max output tokens
        },
    }

    t0 = time.monotonic()
    try:
        with httpx.Client(timeout=OLLAMA_TIMEOUT) as client:
            resp = client.post(f"{OLLAMA_HOST}/api/generate", json=payload)
            resp.raise_for_status()
            data = resp.json()

        duration = time.monotonic() - t0
        text     = data.get("response", "").strip()

        log_llm_call(session_id, model, int(token_estimate), duration, bool(text))
        llm_log.info(f"[{session_id}] Generation complete in {duration:.1f}s "
                     f"({len(text)} chars output)")
        return text

    except httpx.TimeoutException:
        duration = time.monotonic() - t0
        log_llm_call(session_id, model, int(token_estimate), duration, False)
        raise RuntimeError(
            f"Ollama timed out after {OLLAMA_TIMEOUT}s. "
            "Try a smaller model or increase OLLAMA_TIMEOUT."
        )
    except Exception as e:
        duration = time.monotonic() - t0
        log_llm_call(session_id, model, int(token_estimate), duration, False)
        raise RuntimeError(f"Ollama API error: {e}") from e


def generate_stream(
    session_id: str,
    router_name: str,
    outputs: list,
    extra_context: Optional[str] = None,
    model: Optional[str] = None,
) -> Generator[str, None, None]:
    """
    Streaming variant — yields text chunks as they arrive from Ollama.
    Use with FastAPI StreamingResponse.
    """
    model  = model or OLLAMA_MODEL
    prompt = build_prompt(router_name, outputs, extra_context)

    payload = {
        "model":  model,
        "prompt": prompt,
        "system": _SYSTEM_PROMPT,
        "stream": True,
        "options": {
            "num_ctx":     OLLAMA_CONTEXT,
            "temperature": 0.15,
            "top_p":       0.9,
            "num_predict": 4096,
        },
    }

    with httpx.Client(timeout=OLLAMA_TIMEOUT) as client:
        with client.stream("POST", f"{OLLAMA_HOST}/api/generate",
                           json=payload) as resp:
            resp.raise_for_status()
            for line in resp.iter_lines():
                if line:
                    try:
                        chunk = json.loads(line)
                        token = chunk.get("response", "")
                        if token:
                            yield token
                        if chunk.get("done"):
                            break
                    except json.JSONDecodeError:
                        continue
