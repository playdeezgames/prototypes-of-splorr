#!/usr/bin/env bash
# Builds and remakes assets/screenshots/ (headless Chrome, scripted key presses).
set -euo pipefail
cd "$(dirname "$0")/.."
tools/build.sh >/dev/null
python3 tools/make_shots.py "$@"
# End Zone in real time over the DevTools protocol (needs node): coin toss, kick, three plays.
if [ $# -eq 0 ] || [[ " $* " == *" 13-end-zone "* ]]; then
  python3 -m http.server 8790 -d build/web >/dev/null 2>&1 & srv=$!
  trap 'kill $srv' EXIT
  sleep 1
  node tools/rt_shot.mjs http://127.0.0.1:8790/end-zone/index.html 1024 640 assets/screenshots/13-end-zone.png 2500 \
    '[[0,"2"],[1200," "],[2400,"D"],[4400," "],[5600,"A"],[7600," "],[8800,"C"],[10800," "],[12000,"F"],[14000," "],[15200,"B"]]'
fi
