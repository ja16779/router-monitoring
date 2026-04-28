"""
netdoc-ai :: FastAPI Application
Air-gapped Network Design Document generator.
"""
import json
import os
import uuid
from datetime import datetime
from pathlib import Path
from typing import List, Optional

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import (
    FileResponse,
    HTMLResponse,
    JSONResponse,
    StreamingResponse,
)
from fastapi.staticfiles import StaticFiles

from backend import config
from backend.auth import require_permission, verify_api_key, verify_ip
from backend.audit_logger import app_log, log_report_generated, log_request
from backend.models import DocRequest, DocResponse, HealthResponse
from backend.ollama_client import generate_document, generate_stream, health_check
from backend.report_generator import pdf_available, save_html, save_pdf
from backend.ssh_client import collect_router_data

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="NetDocAI",
    description="Air-gapped Network Design Document Generator — Citi POC",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8080", "http://127.0.0.1:8080",
                   "http://localhost:5173"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve frontend
_FRONTEND = Path(__file__).parent.parent / "frontend"
if _FRONTEND.exists():
    app.mount("/static", StaticFiles(directory=str(_FRONTEND)), name="static")


# ── Health ────────────────────────────────────────────────────────────────────
@app.get("/api/health", response_model=HealthResponse, tags=["system"])
async def health():
    online, model = health_check()
    return HealthResponse(
        status="ok" if online else "degraded",
        ollama_online=online,
        model_loaded=model,
    )


@app.get("/api/models", tags=["system"])
async def list_models(_ip: str = Depends(verify_ip),
                      _key: str = Depends(verify_api_key)):
    """List all locally available Ollama models."""
    import httpx
    try:
        with httpx.Client(timeout=5) as client:
            r = client.get(f"{config.OLLAMA_HOST}/api/tags")
            return r.json()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Ollama unreachable: {e}")


# ── Main generation endpoint ──────────────────────────────────────────────────
@app.post("/api/generate", response_model=DocResponse, tags=["generation"])
async def generate(
    req: DocRequest,
    request: Request,
    role: str = Depends(require_permission("generate")),
):
    session_id = str(uuid.uuid4())
    caller_ip  = request.client.host if request.client else "unknown"
    t_start    = datetime.utcnow()

    log_request(session_id, caller_ip, role, req.router_name)
    app_log.info(f"[{session_id}] Generate request: router={req.router_name} role={role}")

    warnings: List[str] = []

    # ── Resolve router IP ─────────────────────────────────────────────────────
    router_ip = req.router_ip or req.router_name

    # ── Collect CLI data via SSH ──────────────────────────────────────────────
    app_log.info(f"[{session_id}] SSH collection starting")
    ssh_result = collect_router_data(
        session_id=session_id,
        router_name=req.router_name,
        router_ip=router_ip,
        override_commands=req.commands,
    )

    if not ssh_result.connected:
        err = ssh_result.error or "SSH connection failed"
        app_log.error(f"[{session_id}] {err}")
        raise HTTPException(status_code=502, detail=err)

    if not ssh_result.outputs:
        raise HTTPException(status_code=502,
                            detail="Connected but no command output collected")

    failed = [o for o in ssh_result.outputs if o.error]
    if failed:
        warnings.extend([f"Command '{o.label}' failed: {o.error}"
                         for o in failed])

    # ── LLM document generation ───────────────────────────────────────────────
    app_log.info(f"[{session_id}] Starting LLM generation with {config.OLLAMA_MODEL}")
    try:
        document = generate_document(
            session_id=session_id,
            router_name=req.router_name,
            outputs=ssh_result.outputs,
            extra_context=req.extra_context,
        )
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    # ── Save reports ──────────────────────────────────────────────────────────
    html_path = save_html(
        session_id=session_id,
        router_name=req.router_name,
        markdown_text=document,
        model=config.OLLAMA_MODEL,
    )
    pdf_path: Optional[str] = None
    if req.include_pdf:
        pdf_path = save_pdf(html_path)
        if not pdf_path and pdf_available():
            warnings.append("PDF generation failed; HTML report available.")
        elif not pdf_available():
            warnings.append("PDF unavailable — install weasyprint for PDF output.")

    # ── Persist session JSON ──────────────────────────────────────────────────
    session_file = config.SESSION_DIR / f"{session_id}.json"
    config.SESSION_DIR.mkdir(parents=True, exist_ok=True)
    session_file.write_text(json.dumps({
        "session_id":  session_id,
        "router_name": req.router_name,
        "router_ip":   router_ip,
        "role":        role,
        "caller_ip":   caller_ip,
        "generated_at": t_start.isoformat(),
        "html_report": html_path,
        "pdf_report":  pdf_path,
        "warnings":    warnings,
        "model":       config.OLLAMA_MODEL,
    }), encoding="utf-8")

    log_report_generated(session_id, req.router_name, html_path, pdf_path)

    duration = (datetime.utcnow() - t_start).total_seconds()
    app_log.info(f"[{session_id}] Done in {duration:.1f}s")

    return DocResponse(
        session_id=session_id,
        router_name=req.router_name,
        status="success" if not failed else "partial",
        document=document,
        html_report=html_path,
        pdf_report=pdf_path,
        warnings=warnings,
        generated_at=t_start,
        model_used=config.OLLAMA_MODEL,
        duration_sec=duration,
    )


# ── Streaming endpoint ────────────────────────────────────────────────────────
@app.post("/api/generate/stream", tags=["generation"])
async def generate_streamed(
    req: DocRequest,
    request: Request,
    role: str = Depends(require_permission("generate")),
):
    """
    Same as /api/generate but streams LLM tokens as Server-Sent Events.
    The SSH collection still happens synchronously first.
    """
    session_id = str(uuid.uuid4())
    router_ip  = req.router_ip or req.router_name

    ssh_result = collect_router_data(session_id, req.router_name, router_ip)
    if not ssh_result.connected:
        raise HTTPException(status_code=502,
                            detail=ssh_result.error or "SSH failed")

    def _stream():
        try:
            for chunk in generate_stream(session_id, req.router_name,
                                         ssh_result.outputs, req.extra_context):
                yield f"data: {json.dumps({'token': chunk})}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(_stream(), media_type="text/event-stream")


# ── Report download ───────────────────────────────────────────────────────────
@app.get("/api/reports/{filename}", tags=["reports"])
async def download_report(
    filename: str,
    _ip:  str = Depends(verify_ip),
    _key: str = Depends(verify_api_key),
):
    """Download a generated HTML or PDF report by filename."""
    # Prevent path traversal
    if ".." in filename or "/" in filename or "\\" in filename:
        raise HTTPException(status_code=400, detail="Invalid filename")
    fpath = config.REPORT_DIR / filename
    if not fpath.exists():
        raise HTTPException(status_code=404, detail="Report not found")
    return FileResponse(str(fpath))


# ── Session history ───────────────────────────────────────────────────────────
@app.get("/api/sessions", tags=["history"])
async def list_sessions(
    limit: int = 20,
    role: str = Depends(require_permission("history")),
):
    """Return the most recent N session records."""
    sessions = []
    for f in sorted(config.SESSION_DIR.glob("*.json"),
                    key=lambda x: x.stat().st_mtime, reverse=True)[:limit]:
        try:
            sessions.append(json.loads(f.read_text(encoding="utf-8")))
        except Exception:
            pass
    return {"sessions": sessions, "total": len(sessions)}


# ── Frontend catch-all ────────────────────────────────────────────────────────
@app.get("/", response_class=HTMLResponse, include_in_schema=False)
@app.get("/{path:path}", response_class=HTMLResponse, include_in_schema=False)
async def serve_frontend(path: str = ""):
    index = _FRONTEND / "index.html"
    if index.exists():
        return HTMLResponse(index.read_text(encoding="utf-8"))
    return HTMLResponse("<h1>NetDocAI</h1><p>Frontend not found. "
                        "See <a href='/api/docs'>API docs</a>.</p>")
