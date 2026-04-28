#!/usr/bin/env bash
# netdoc-ai :: Quick health check
PORT="${PORT:-8080}"
echo "=== NetDocAI Health Check ==="
echo ""
echo "--- Backend API ---"
curl -s "http://localhost:${PORT}/api/health" | python3 -m json.tool 2>/dev/null || \
  echo "  Backend not reachable on port ${PORT}"
echo ""
echo "--- Ollama ---"
curl -s "http://localhost:11434/api/tags" | python3 -c "
import sys, json
d = json.load(sys.stdin)
models = [m['name'] for m in d.get('models', [])]
print(f'  Models installed: {len(models)}')
for m in models: print(f'    - {m}')
" 2>/dev/null || echo "  Ollama not reachable"
