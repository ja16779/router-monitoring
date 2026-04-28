/* NetDocAI — Frontend Application */
'use strict';

const API = '';  // same origin
let currentSession = null;
let currentDoc     = null;
let rawOutputData  = [];

// ── Init ──────────────────────────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', () => {
  checkHealth();
  loadSessions();
  setInterval(checkHealth, 30_000);
});

// ── Health check ──────────────────────────────────────────────────────────────
async function checkHealth() {
  const dot  = document.getElementById('statusDot');
  const text = document.getElementById('statusText');
  const info = document.getElementById('sysInfo');
  try {
    const r = await fetch(`${API}/api/health`);
    const d = await r.json();
    const online = d.ollama_online;
    dot.className  = 'status-dot ' + (online ? 'online' : 'offline');
    text.textContent = online
      ? `Ollama ✓ ${d.model_loaded || ''}`
      : 'Ollama offline';
    info.innerHTML = `
      <div class="sys-row"><span>Ollama</span>
        <span class="sys-val ${online?'ok':'bad'}">${online ? '● Online' : '● Offline'}</span></div>
      <div class="sys-row"><span>Model</span>
        <span class="sys-val">${d.model_loaded || '—'}</span></div>
      <div class="sys-row"><span>API status</span>
        <span class="sys-val ok">${d.status}</span></div>
      <div class="sys-row"><span>Version</span>
        <span class="sys-val">${d.version}</span></div>
    `;
  } catch {
    dot.className    = 'status-dot offline';
    text.textContent = 'Backend offline';
    info.innerHTML   = '<div class="sys-val bad">● Cannot reach API</div>';
  }
}

// ── Headers helper ────────────────────────────────────────────────────────────
function getHeaders() {
  return {
    'Content-Type':  'application/json',
    'X-API-Key':     document.getElementById('apiKey').value.trim(),
    'X-User-Role':   document.getElementById('roleSelect').value,
  };
}

// ── Main: Generate document ───────────────────────────────────────────────────
async function generate() {
  const routerName = document.getElementById('routerName').value.trim();
  if (!routerName) { showAlert('Please enter a router hostname or IP.', 'error'); return; }

  const stream = document.getElementById('streamMode').checked;
  stream ? await generateStream(routerName) : await generateFull(routerName);
}

async function generateFull(routerName) {
  const btn = document.getElementById('generateBtn');
  btn.disabled = true;
  btn.innerHTML = '<span class="spinner"></span> Working…';

  hideWelcome();
  showProgress(0);
  clearAlert();

  const body = {
    router_name:   routerName,
    router_ip:     document.getElementById('routerIp').value.trim() || null,
    role:          document.getElementById('roleSelect').value,
    extra_context: document.getElementById('extraContext').value.trim() || null,
    include_pdf:   document.getElementById('includePdf').checked,
  };

  try {
    setStep(1, 'active');  // SSH connect
    const r = await fetch(`${API}/api/generate`, {
      method:  'POST',
      headers: getHeaders(),
      body:    JSON.stringify(body),
    });

    setStep(1, 'done'); setStep(2, 'done'); setStep(3, 'active');

    if (!r.ok) {
      const err = await r.json().catch(() => ({ detail: r.statusText }));
      throw new Error(err.detail || `HTTP ${r.status}`);
    }

    setStep(3, 'done'); setStep(4, 'active');
    const data = await r.json();
    setStep(4, 'done');
    setProgress(100);

    currentSession = data;
    currentDoc     = data.document;

    renderDocument(data, routerName);

    if (data.warnings?.length) {
      showAlert('⚠ ' + data.warnings.join('<br>⚠ '), 'warning');
    } else {
      showAlert(`✓ Document generated in ${data.duration_sec?.toFixed(1)}s — Model: ${data.model_used}`, 'success');
    }
    loadSessions();

  } catch (e) {
    setStep(null, 'error');
    showAlert(`Error: ${e.message}`, 'error');
    console.error(e);
  } finally {
    btn.disabled = false;
    btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polygon points="5 3 19 12 5 21 5 3"/></svg> Generate Document';
  }
}

async function generateStream(routerName) {
  const btn = document.getElementById('generateBtn');
  btn.disabled = true;
  btn.innerHTML = '<span class="spinner"></span> Streaming…';

  hideWelcome();
  showProgress(50);
  clearAlert();

  const body = {
    router_name:   routerName,
    router_ip:     document.getElementById('routerIp').value.trim() || null,
    role:          document.getElementById('roleSelect').value,
    extra_context: document.getElementById('extraContext').value.trim() || null,
    include_pdf:   false,
  };

  const streamDiv = document.getElementById('streamOutput');
  streamDiv.textContent = '';
  streamDiv.style.display = 'block';
  document.getElementById('markdownOutput').style.display = 'none';
  document.getElementById('previewOutput').style.display  = 'none';
  document.getElementById('rawOutput').style.display      = 'none';
  showTabs();

  let fullText = '';
  try {
    const r = await fetch(`${API}/api/generate/stream`, {
      method:  'POST',
      headers: getHeaders(),
      body:    JSON.stringify(body),
    });

    const reader = r.body.getReader();
    const dec    = new TextDecoder();
    const cursor = document.createElement('span');
    cursor.className   = 'cursor-blink';
    cursor.textContent = '▌';
    streamDiv.appendChild(cursor);

    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      const text = dec.decode(value);
      for (const line of text.split('\n')) {
        if (!line.startsWith('data:')) continue;
        const payload = line.slice(5).trim();
        if (payload === '[DONE]') break;
        try {
          const chunk = JSON.parse(payload);
          if (chunk.token) {
            fullText += chunk.token;
            streamDiv.insertBefore(document.createTextNode(chunk.token), cursor);
            streamDiv.scrollTop = streamDiv.scrollHeight;
          }
          if (chunk.error) showAlert('Error: ' + chunk.error, 'error');
        } catch {}
      }
    }
    cursor.remove();
    currentDoc = fullText;
    setProgress(100);
  } catch (e) {
    showAlert(`Stream error: ${e.message}`, 'error');
  } finally {
    btn.disabled = false;
    btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polygon points="5 3 19 12 5 21 5 3"/></svg> Generate Document';
  }
}

// ── Render ────────────────────────────────────────────────────────────────────
function renderDocument(data, routerName) {
  document.getElementById('markdownOutput').textContent = data.document || '';
  document.getElementById('markdownOutput').style.display = 'block';

  // Simple markdown preview (headings, bold, code, tables)
  let html = (data.document || '')
    .replace(/^#{1} (.+)$/gm, '<h1>$1</h1>')
    .replace(/^#{2} (.+)$/gm, '<h2>$1</h2>')
    .replace(/^#{3} (.+)$/gm, '<h3>$1</h3>')
    .replace(/```[\s\S]*?```/g, m => `<pre><code>${escHtml(m.slice(3,-3))}</code></pre>`)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\n\n/g, '</p><p>')
    .replace(/^\|(.+)$/gm, row => {
      const cells = row.split('|').slice(1,-1)
        .map(c => `<td>${c.trim()}</td>`).join('');
      return `<tr>${cells}</tr>`;
    });
  html = `<p>${html}</p>`;
  document.getElementById('previewOutput').innerHTML =
    `<div style="font-family:'Segoe UI',sans-serif;line-height:1.7">${html}</div>`;

  currentSession = data;
  showTabs();
  switchTab('markdown');

  // Update download buttons
  document.getElementById('downloadHtml').style.display = data.html_report ? '' : 'none';
  document.getElementById('downloadPdf').style.display  = data.pdf_report  ? '' : 'none';
}

function escHtml(t) {
  return t.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

// ── Tabs ──────────────────────────────────────────────────────────────────────
function switchTab(tab) {
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.getElementById('markdownOutput').style.display = 'none';
  document.getElementById('previewOutput').style.display  = 'none';
  document.getElementById('rawOutput').style.display      = 'none';
  document.getElementById('streamOutput').style.display   = 'none';

  const tabEl = [...document.querySelectorAll('.tab')]
    .find(t => t.textContent.trim().toLowerCase().startsWith(tab));
  if (tabEl) tabEl.classList.add('active');

  if (tab === 'markdown') document.getElementById('markdownOutput').style.display = 'block';
  if (tab === 'preview')  document.getElementById('previewOutput').style.display  = 'block';
  if (tab === 'raw')      document.getElementById('rawOutput').style.display      = 'block';
}

// ── Download ──────────────────────────────────────────────────────────────────
async function downloadFile(type) {
  if (!currentSession) return;
  const path = type === 'html' ? currentSession.html_report : currentSession.pdf_report;
  if (!path) { showAlert(`No ${type.toUpperCase()} report available.`, 'warning'); return; }
  const fname = path.split(/[/\\]/).pop();
  const r = await fetch(`${API}/api/reports/${fname}`, { headers: getHeaders() });
  if (!r.ok) { showAlert('Download failed.', 'error'); return; }
  const blob = await r.blob();
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = fname;
  a.click();
  URL.revokeObjectURL(a.href);
}

function copyMarkdown() {
  if (currentDoc) {
    navigator.clipboard.writeText(currentDoc)
      .then(() => showAlert('Copied to clipboard!', 'success'))
      .catch(() => showAlert('Copy failed — use Ctrl+A in the output area.', 'warning'));
  }
}

// ── Sessions ──────────────────────────────────────────────────────────────────
async function loadSessions() {
  try {
    const r = await fetch(`${API}/api/sessions`, { headers: getHeaders() });
    if (!r.ok) return;
    const d = await r.json();
    const list = document.getElementById('sessionList');
    if (!d.sessions?.length) {
      list.innerHTML = '<div class="empty-hint">No sessions yet</div>';
      return;
    }
    list.innerHTML = d.sessions.map(s => `
      <div class="session-item" onclick="loadSession('${s.session_id}')">
        <div class="session-router">🖧 ${s.router_name}</div>
        <div class="session-meta">
          ${new Date(s.generated_at).toLocaleString()} &nbsp;·&nbsp; ${s.role}
          ${s.warnings?.length ? ' ⚠ ' + s.warnings.length + ' warning(s)' : ''}
        </div>
      </div>
    `).join('');
  } catch {}
}

function loadSession(sessionId) {
  showAlert(`Session ${sessionId.slice(0,8)}… loaded — re-run to refresh document.`, 'warning');
}

// ── Progress helpers ──────────────────────────────────────────────────────────
function showProgress(pct) {
  const wrap = document.getElementById('progressWrap');
  wrap.style.display = 'block';
  document.getElementById('progressFill').style.width = pct + '%';
}
function setProgress(pct) {
  document.getElementById('progressFill').style.width = pct + '%';
}
function setStep(num, state) {
  for (let i = 1; i <= 4; i++) {
    const el = document.getElementById('step' + i);
    if (!el) continue;
    if (i < num) el.className = 'progress-step done';
    else if (i === num) el.className = 'progress-step ' + state;
    else el.className = 'progress-step';
  }
}
function showTabs() {
  document.getElementById('tabBar').style.display = 'flex';
}
function hideWelcome() {
  document.getElementById('welcomeScreen').style.display = 'none';
}

// ── Alerts ────────────────────────────────────────────────────────────────────
function showAlert(msg, type) {
  const box = document.getElementById('alertBox');
  box.className  = 'alert-box ' + type;
  box.innerHTML  = msg;
  box.style.display = 'block';
  if (type === 'success') setTimeout(() => { box.style.display = 'none'; }, 5000);
}
function clearAlert() {
  document.getElementById('alertBox').style.display = 'none';
}
