@echo off
:: ─────────────────────────────────────────────────────────────────────────────
:: netdoc-ai :: Windows Installation Script
:: Run as: install.bat
:: Requires: Python 3.10+, pip, internet access (first run only)
:: ─────────────────────────────────────────────────────────────────────────────
setlocal enabledelayedexpansion

echo.
echo ============================================================
echo   NetDocAI — Air-Gapped Network Documentation System
echo   Installation Script for Windows
echo ============================================================
echo.

:: Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python not found. Install Python 3.10+ from python.org
    pause & exit /b 1
)
for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set PYVER=%%v
echo [OK] Python %PYVER%

:: Navigate to project root (parent of scripts/)
cd /d "%~dp0.."
set ROOT=%CD%
echo [INFO] Project root: %ROOT%

:: Create .env if not exists
if not exist ".env" (
    copy ".env.example" ".env" >nul
    echo [INFO] Created .env from template — EDIT .env before use!
) else (
    echo [OK] .env already exists
)

:: Create venv
if not exist "venv" (
    echo [INFO] Creating Python virtual environment...
    python -m venv venv
    echo [OK] venv created
) else (
    echo [OK] venv already exists
)

:: Activate venv and install deps
echo [INFO] Installing Python dependencies...
call venv\Scripts\activate.bat
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet
if errorlevel 1 (
    echo [ERROR] pip install failed. Check your internet connection.
    pause & exit /b 1
)
echo [OK] Python dependencies installed

:: Optional: weasyprint for PDF
echo.
echo [OPTIONAL] Install weasyprint for PDF generation?
set /p WPDF="Install weasyprint? (y/N): "
if /i "%WPDF%"=="y" (
    pip install weasyprint --quiet
    echo [OK] weasyprint installed
)

:: Check / install Ollama
echo.
where ollama >nul 2>&1
if errorlevel 1 (
    echo [INFO] Ollama not found. Downloading installer...
    powershell -Command "Invoke-WebRequest -Uri 'https://ollama.com/download/OllamaSetup.exe' -OutFile '%TEMP%\OllamaSetup.exe'"
    echo [INFO] Running Ollama installer (follow prompts)...
    start /wait %TEMP%\OllamaSetup.exe
    echo [INFO] After installation, restart this script or run: ollama pull mistral:7b
) else (
    echo [OK] Ollama already installed
)

:: Pull model
echo.
where ollama >nul 2>&1
if not errorlevel 1 (
    echo [INFO] Pulling mistral:7b model (this may take several minutes on first run)...
    ollama pull mistral:7b
    echo [OK] Model ready
)

:: Create placeholder files
echo. > "%ROOT%\logs\.gitkeep" 2>nul
echo. > "%ROOT%\reports\.gitkeep" 2>nul

echo.
echo ============================================================
echo   Installation Complete!
echo ============================================================
echo.
echo   Next steps:
echo   1. Edit .env with your jump host and router credentials
echo   2. Run: start.bat
echo   3. Open: http://localhost:8080
echo.
pause
