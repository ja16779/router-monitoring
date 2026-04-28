@echo off
:: ─────────────────────────────────────────────────────────────────────────────
:: netdoc-ai :: Windows Start Script
:: Run from project root: scripts\start.bat  OR  start.bat (from root)
:: ─────────────────────────────────────────────────────────────────────────────
setlocal

cd /d "%~dp0.."
set ROOT=%CD%

echo.
echo ============================================================
echo   NetDocAI — Starting Services
echo ============================================================
echo.

:: Check venv
if not exist "venv\Scripts\activate.bat" (
    echo [ERROR] Virtual environment not found. Run scripts\install.bat first.
    pause & exit /b 1
)
call venv\Scripts\activate.bat

:: Check .env
if not exist ".env" (
    echo [WARNING] .env not found — using defaults. Copy .env.example to .env
)

:: Start Ollama in background (if not already running)
tasklist /FI "IMAGENAME eq ollama.exe" 2>nul | find /i "ollama.exe" >nul
if errorlevel 1 (
    echo [INFO] Starting Ollama service...
    start /min "" ollama serve
    timeout /t 3 /nobreak >nul
) else (
    echo [OK] Ollama already running
)

:: Start FastAPI
echo [INFO] Starting NetDocAI backend on http://localhost:8080
echo [INFO] Press Ctrl+C to stop
echo.
python -m uvicorn backend.main:app --host 127.0.0.1 --port 8080 --reload

pause
