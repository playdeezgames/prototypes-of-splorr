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
# February and March 1979 in real time: a Prize Board pair turned up, an Elements Quiz question, a Dive Bomb
# pass, Jig Saw tries, a Tarot reading and the Fog Index editor with a sample in it.
if [ $# -eq 0 ] || [[ " $* " == *" 26-31 "* ]]; then
  python3 -m http.server 8792 -d build/web >/dev/null 2>&1 & srv3=$!
  trap 'kill $srv3' EXIT
  sleep 1
  U=http://127.0.0.1:8792
  node tools/rt_shot.mjs $U/prize-board/index.html 768 480 assets/screenshots/26-prize-board.png 700 \
    '[[0,"2"],[900,"5"],[1100,"Enter"],[2200,"1"],[2300,"2"],[2500,"Enter"]]'
  node tools/rt_shot.mjs $U/elements-quiz/index.html 768 480 assets/screenshots/27-elements-quiz.png 1500 '[[0,"1"]]'
  node tools/rt_shot.mjs $U/dive-bomb/index.html 768 480 assets/screenshots/28-dive-bomb.png 1200 '[[0,"1"],[2500,"z"]]'
  node tools/rt_shot.mjs $U/jig-saw/index.html 768 480 assets/screenshots/29-jig-saw.png 800 '[[0,"1"],[800,"6"],[1300,"7"],[1800,"3"]]'
  node tools/rt_shot.mjs $U/tarot/index.html 768 480 assets/screenshots/30-tarot.png 1800 \
    '[[0,"W"],[90,"I"],[180,"L"],[270,"L"],[360," "],[450,"I"],[540,"T"],[630," "],[720,"R"],[810,"A"],[900,"I"],[990,"N"],[1080," "],[1170,"T"],[1260,"O"],[1350,"D"],[1440,"A"],[1530,"Y"],[1620,"?"],[2000,"Enter"],[3000,"Enter"],[4100,"Enter"],[5200,"Enter"],[6300,"Enter"],[7400,"Enter"]]'
  node tools/rt_shot.mjs $U/fog-index/index.html 768 480 assets/screenshots/31-fog-index.png 800 '[[0,"2"],[500,"2"],[1300,"Enter"]]'
fi
