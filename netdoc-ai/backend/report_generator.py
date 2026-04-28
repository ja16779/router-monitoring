"""
netdoc-ai :: Report Generator
Converts the LLM-generated Markdown document into:
  1. A styled HTML file  (always)
  2. A PDF file          (when weasyprint is available)
"""
import re
import shutil
from datetime import datetime
from pathlib import Path
from typing import Optional

from backend.config import REPORT_DIR
from backend.audit_logger import app_log

REPORT_DIR.mkdir(parents=True, exist_ok=True)

# ── Try importing optional PDF engine ────────────────────────────────────────
try:
    from weasyprint import HTML as WeasyprintHTML
    _PDF_AVAILABLE = True
except ImportError:
    _PDF_AVAILABLE = False
    app_log.warning("weasyprint not installed — PDF generation disabled. "
                    "Run: pip install weasyprint")

# ── Try importing markdown renderer ──────────────────────────────────────────
try:
    import markdown as _md
    def md_to_html(text: str) -> str:
        return _md.markdown(
            text,
            extensions=["tables", "fenced_code", "toc", "attr_list"],
        )
except ImportError:
    def md_to_html(text: str) -> str:  # type: ignore[misc]
        # Minimal fallback: wrap paragraphs and code blocks
        text = re.sub(r"```.*?```", lambda m: f"<pre><code>{m.group()}</code></pre>",
                      text, flags=re.DOTALL)
        text = re.sub(r"^#{1,6} (.+)$",
                      lambda m: f"<h{m.group().count('#')}>{m.group(1)}</h{m.group().count('#')}>",
                      text, flags=re.M)
        text = text.replace("\n\n", "</p><p>")
        return f"<p>{text}</p>"


# ── HTML template ─────────────────────────────────────────────────────────────
_HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Network Design Document — {router}</title>
<style>
  :root {{
    --citi-blue: #003f7f;
    --citi-red:  #e4002b;
    --bg:        #f5f7fa;
    --card:      #ffffff;
    --text:      #1a1a2e;
    --border:    #d0d7de;
    --code-bg:   #0d1117;
    --code-fg:   #c9d1d9;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
    font-size: 14px;
    line-height: 1.7;
    color: var(--text);
    background: var(--bg);
    padding: 32px;
  }}
  .wrapper {{ max-width: 1100px; margin: 0 auto; }}
  header {{
    background: var(--citi-blue);
    color: #fff;
    padding: 24px 32px;
    border-radius: 8px 8px 0 0;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }}
  header h1 {{ font-size: 1.5rem; font-weight: 700; letter-spacing: .5px; }}
  header .meta {{ font-size: 12px; opacity: .8; text-align: right; line-height: 1.6; }}
  .confidential {{
    background: var(--citi-red);
    color: #fff;
    text-align: center;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 2px;
    padding: 4px;
  }}
  .content {{
    background: var(--card);
    border: 1px solid var(--border);
    border-top: none;
    padding: 40px;
    border-radius: 0 0 8px 8px;
  }}
  h1,h2,h3,h4,h5,h6 {{
    color: var(--citi-blue);
    margin: 1.5em 0 .5em;
    line-height: 1.3;
  }}
  h1 {{ font-size: 1.8rem; border-bottom: 3px solid var(--citi-blue); padding-bottom: 8px; }}
  h2 {{ font-size: 1.35rem; border-bottom: 1px solid var(--border); padding-bottom: 4px; }}
  h3 {{ font-size: 1.1rem; color: #0056b3; }}
  p  {{ margin: .7em 0; }}
  ul,ol {{ margin: .5em 0 .5em 1.8em; }}
  li {{ margin: .25em 0; }}
  table {{
    width: 100%;
    border-collapse: collapse;
    margin: 1em 0;
    font-size: 13px;
  }}
  th {{
    background: var(--citi-blue);
    color: #fff;
    padding: 8px 12px;
    text-align: left;
    font-weight: 600;
  }}
  td {{ padding: 7px 12px; border-bottom: 1px solid var(--border); }}
  tr:nth-child(even) {{ background: var(--bg); }}
  pre,code {{
    font-family: 'Cascadia Code','Consolas','Courier New',monospace;
    font-size: 12px;
  }}
  pre {{
    background: var(--code-bg);
    color: var(--code-fg);
    padding: 16px 20px;
    border-radius: 6px;
    overflow-x: auto;
    margin: 1em 0;
    border-left: 4px solid var(--citi-blue);
  }}
  code {{ background: #eef1f5; padding: 1px 5px; border-radius: 3px; color: #c0392b; }}
  pre code {{ background: none; color: inherit; padding: 0; }}
  blockquote {{
    border-left: 4px solid var(--citi-red);
    padding: 8px 16px;
    margin: 1em 0;
    background: #fff5f5;
    border-radius: 0 4px 4px 0;
  }}
  .risk-high   {{ color: #c0392b; font-weight: 700; }}
  .risk-medium {{ color: #d68910; font-weight: 700; }}
  .risk-low    {{ color: #1e8449; font-weight: 700; }}
  footer {{
    margin-top: 32px;
    padding-top: 16px;
    border-top: 1px solid var(--border);
    font-size: 11px;
    color: #888;
    text-align: center;
  }}
  @media print {{
    body {{ padding: 0; background: #fff; }}
    pre  {{ page-break-inside: avoid; }}
    h2   {{ page-break-before: auto; }}
  }}
</style>
</head>
<body>
<div class="wrapper">
  <div class="confidential">INTERNAL USE ONLY — CITI CONFIDENTIAL</div>
  <header>
    <div>
      <h1>Network Design Document</h1>
      <div style="font-size:13px;opacity:.9;margin-top:4px;">Device: <strong>{router}</strong></div>
    </div>
    <div class="meta">
      Generated: {generated_at}<br>
      Model: {model}<br>
      Session: {session_id}
    </div>
  </header>
  <div class="content">
    {body}
  </div>
  <footer>
    Generated by NetDocAI — Air-Gapped LLM Network Documentation System &nbsp;|&nbsp;
    {generated_at} &nbsp;|&nbsp; FOR INTERNAL USE ONLY
  </footer>
</div>
</body>
</html>"""


# ── Public API ────────────────────────────────────────────────────────────────

def save_html(
    session_id: str,
    router_name: str,
    markdown_text: str,
    model: str,
) -> str:
    """Render markdown → HTML and save to REPORT_DIR. Returns file path."""
    body    = md_to_html(markdown_text)
    ts      = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    fname   = f"{router_name}_{ts}_{session_id[:8]}.html"
    fpath   = REPORT_DIR / fname

    html = _HTML_TEMPLATE.format(
        router       = router_name,
        generated_at = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC"),
        model        = model,
        session_id   = session_id,
        body         = body,
    )
    fpath.write_text(html, encoding="utf-8")
    app_log.info(f"HTML report saved: {fpath}")
    return str(fpath)


def save_pdf(html_path: str) -> Optional[str]:
    """Convert existing HTML file → PDF. Returns PDF path or None if unavailable."""
    if not _PDF_AVAILABLE:
        return None
    html_p = Path(html_path)
    pdf_p  = html_p.with_suffix(".pdf")
    try:
        WeasyprintHTML(filename=str(html_p)).write_pdf(str(pdf_p))
        app_log.info(f"PDF report saved: {pdf_p}")
        return str(pdf_p)
    except Exception as e:
        app_log.error(f"PDF generation failed: {e}")
        return None


def pdf_available() -> bool:
    return _PDF_AVAILABLE
