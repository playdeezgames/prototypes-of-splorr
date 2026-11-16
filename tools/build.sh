#!/usr/bin/env bash
# Builds one prototype (or all with no name) into build/web/<game>/, plus the hub page.
# Usage: tools/build.sh [game ...] [--size]
set -euo pipefail
cd "$(dirname "$0")/.."
ODIN="${ODIN:-odin}"
opt=speed
games=()
for a in "$@"; do
  if [[ "$a" == "--size" ]]; then opt=size; else games+=("${a%/}"); fi
done
if [[ ${#games[@]} -eq 0 ]]; then
  for d in */odin/web; do games+=("${d%%/*}"); done
fi
mkdir -p build/web
cp web/index.html build/web/
for g in "${games[@]}"; do
  out="build/web/$g"
  rm -rf "$out"
  mkdir -p "$out"
  "$ODIN" build "$g/odin/web" -target:js_wasm32 -out:"$out/game.wasm" -o:$opt \
    -collection:proto=shared/odin -vet-unused -vet-shadowing
  cp "$("$ODIN" root)/core/sys/wasm/js/odin.js" "$out/"
  cp shared/web/shim.js shared/web/lootlocker.js shared/web/PublicPixel.ttf shared/web/PublicPixel-LICENSE.txt "$out/"
  cp -r "$g/web/." "$out/"
  echo "built $out ($opt)"
done
