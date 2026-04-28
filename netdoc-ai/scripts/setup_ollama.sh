#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# netdoc-ai :: Ollama setup for Linux / macOS / WSL
# Usage: bash scripts/setup_ollama.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

MODEL="${OLLAMA_MODEL:-mistral:7b}"
echo "================================================================"
echo "  NetDocAI — Ollama Setup"
echo "  Target model: $MODEL"
echo "================================================================"

# Detect OS
OS=$(uname -s)
echo "[INFO] OS: $OS"

if ! command -v ollama &>/dev/null; then
  echo "[INFO] Ollama not found — installing..."
  if [[ "$OS" == "Linux" ]]; then
    curl -fsSL https://ollama.com/install.sh | sh
  elif [[ "$OS" == "Darwin" ]]; then
    echo "[INFO] macOS detected — download Ollama.app from https://ollama.com"
    echo "       After installing, run: ollama pull $MODEL"
    exit 0
  else
    echo "[ERROR] Unsupported OS for automatic install: $OS"
    echo "        Visit https://ollama.com/download"
    exit 1
  fi
else
  echo "[OK] Ollama already installed: $(ollama --version)"
fi

# Start Ollama if not running
if ! pgrep -x "ollama" &>/dev/null; then
  echo "[INFO] Starting Ollama service..."
  ollama serve &>/tmp/ollama.log &
  sleep 3
fi

# Pull model
echo "[INFO] Pulling model: $MODEL (may take a while on first run)"
ollama pull "$MODEL"

echo ""
echo "[OK] Ollama ready with $MODEL"
echo "     API endpoint: http://localhost:11434"
