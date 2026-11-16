#!/usr/bin/env bash
# Builds every prototype and serves the hub (no caching) at http://localhost:${PORT:-8010}/ (wasm needs http).
set -euo pipefail
cd "$(dirname "$0")/.."
tools/build.sh
exec python3 tools/serve.py "${PORT:-8010}" build/web
