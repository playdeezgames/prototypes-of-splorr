# SoftSide prototypes

Play: https://playdeezgames.github.io/prototypes-of-splorr/ (GitHub Pages, served from `docs/` on `main`; refresh with `tools/pages.sh`, then commit and push).

A folder for prototyping games, started November 15, 2026. The first batch are new takes on the five type-in programs in *SoftSide* magazine, Vol. 1 No. 11 (August 1979): Melt Down, Shooting Gallery, Cryptogram, Morse Code Tutor (gamified) and Storybook (a toy). The listings are catalogued in `sources/softside-v1n11/LISTINGS.md`. The second batch (November 18, 2026) takes all five listings from the first issue, Vol. 1 No. 1 (October 1978): Pillbox, Gunnery Mate (after "Death Star", renamed and given its own setting), State Capital Quiz (gamified), Cribbage, and Calculator (a tool); see `sources/softside-v1n01/LISTINGS.md`. The magazine PDFs are kept locally only and are git-ignored.

Each prototype is Odin compiled to `js_wasm32`: `<game>/odin/game` holds the pure rules (native tests), `<game>/odin/web` the page layer, and `<game>/web/index.html` the page. `shared/` has the canvas/audio shim (`shim.js`, Odin package `proto:gfx`), the Public Pixel font (CC0, GGBotNet) and the LootLocker feedback shim.

```bash
tools/test.sh [game ...]          # native tests, then wasm builds
tools/build.sh [game ...] [--size] # build into build/web/<game>/ plus the hub page
tools/serve.sh                     # build everything, serve http://localhost:8010/ (no-cache)
tools/pages.sh                     # tests, size build, copy into docs/ for GitHub Pages
tools/make_shots.sh                # assets/screenshots/ (headless Chrome)
tools/make_cover.py                # assets/cover.png (630x500, from the screenshots)
./shippit.sh [--push]              # itch.io zip; uploads only with --push (see ITCH_DESCRIPTION.md)
```

Code and words made by an AI agent (Claude Code) at TheGrumpyGameDev's direction.
