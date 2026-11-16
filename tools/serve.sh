#!/usr/bin/env bash
# Builds every prototype and serves the hub at http://localhost:${PORT:-8010}/ (wasm needs http).
set -euo pipefail
cd "$(dirname "$0")/.."
tools/build.sh
exec python3 -m http.server "${PORT:-8010}" -d build/web
