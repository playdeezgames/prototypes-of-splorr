# SoftSide prototypes

A folder for prototyping games, started November 15, 2026. The first batch are new takes on the five type-in programs in *SoftSide* magazine, Vol. 1 No. 11 (August 1979): Melt Down, Shooting Gallery, Cryptogram, Morse Code Tutor (gamified) and Storybook (a toy). The listings are catalogued in `sources/softside-v1n11/LISTINGS.md`. The magazine PDF is kept locally only and is git-ignored.

Each prototype is Odin compiled to `js_wasm32`: `<game>/odin/game` holds the pure rules (native tests), `<game>/odin/web` the page layer, and `<game>/web/index.html` the page. `shared/` has the canvas/audio shim (`shim.js`, Odin package `proto:gfx`), the Public Pixel font (CC0, GGBotNet) and the LootLocker feedback shim.

```bash
tools/test.sh [game ...]          # native tests, then wasm builds
tools/build.sh [game ...] [--size] # build into build/web/<game>/ plus the hub page
tools/serve.sh                     # build everything, serve http://localhost:8010/
```

Code and words made by an AI agent (Claude Code) at TheGrumpyGameDev's direction.
