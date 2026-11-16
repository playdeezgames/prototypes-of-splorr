#!/usr/bin/env bash
# Builds and remakes assets/screenshots/ (headless Chrome, scripted key presses).
set -euo pipefail
cd "$(dirname "$0")/.."
tools/build.sh >/dev/null
python3 tools/make_shots.py
