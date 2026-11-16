#!/usr/bin/env bash
# Native tests of each prototype's rules package (<game>/odin/game), then the wasm builds.
# Usage: tools/test.sh [game ...]   (one thread: tests may share package globals)
set -euo pipefail
cd "$(dirname "$0")/.."
ODIN="${ODIN:-odin}"
games=()
for a in "$@"; do games+=("${a%/}"); done
if [[ ${#games[@]} -eq 0 ]]; then
  for d in */odin/web; do games+=("${d%%/*}"); done
fi
for g in "${games[@]}"; do
  if [[ -d "$g/odin/game" ]]; then
    echo "== $g"
    "$ODIN" test "$g/odin/game" -define:ODIN_TEST_THREADS=1 -o:speed -vet-unused -vet-shadowing
  fi
done
tools/build.sh "${games[@]}"
