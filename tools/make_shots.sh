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
# 'Round the Horn three weeks out, a Ten Pin Bowling ball just rolled and a Kiddy Slot spin, in real time.
if [ $# -eq 0 ] || [[ " $* " == *" 22-round-the-horn "* ]] || [[ " $* " == *" 23-ten-pin-bowling "* ]] || [[ " $* " == *" 24-kiddy-slot "* ]]; then
  python3 -m http.server 8791 -d build/web >/dev/null 2>&1 & srv2=$!
  trap 'kill $srv2' EXIT
  sleep 1
  node tools/rt_shot.mjs http://127.0.0.1:8791/round-the-horn/index.html 768 480 assets/screenshots/22-round-the-horn.png 1800 \
    '[[0,"Enter"],[800,"Enter"],[2300,"Enter"],[3800,"Enter"],[5300,"Enter"],[6800,"Enter"],[8300,"Enter"],[9800,"Enter"],[11300,"Enter"],[12800,"Enter"],[14300,"Enter"]]'
  node tools/rt_shot.mjs http://127.0.0.1:8791/ten-pin-bowling/index.html 768 480 assets/screenshots/23-ten-pin-bowling.png 2300 \
    '[[0,"Enter"],[1700,"ArrowUp"]]'
  node tools/rt_shot.mjs http://127.0.0.1:8791/kiddy-slot/index.html 768 480 assets/screenshots/24-kiddy-slot.png 2600 '[[0,"Enter"]]'
fi
