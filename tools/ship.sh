#!/usr/bin/env bash
# Prepares the itch.io build: tests, a size-optimised web build of the hub page and all five
# prototypes, a zip. Pushes ONLY with --push. Never commits, never deletes anything but its own
# build. Usage: tools/ship.sh [--push]
# Ship only on the user's "ship", on a day Coxswain says is free (ship_today), then ship_complete.
set -euo pipefail
cd "$(dirname "$0")/.."
# Page: https://thegrumpygamedev.itch.io/softside-prototypes (first release; the page must exist on
# itch.io before butler can push to it, and the slug is a guess until it does).
TARGET="thegrumpygamedev/softside-prototypes:html"
ZIP="build/softside-prototypes-html5.zip"

tools/test.sh >/dev/null
rm -rf build/web
tools/build.sh --size
rm -f "$ZIP"
(cd build/web && zip -q -9 -r "../$(basename "$ZIP")" .)
echo "zip: $ZIP ($(du -h "$ZIP" | cut -f1))"
unzip -l "$ZIP" | tail -3

if [ "${1:-}" = "--push" ]; then
	if [ -n "$(git status --porcelain)" ]; then
		echo "note: the working tree has uncommitted changes; what is pushed is the working tree, not a commit"
	fi
	butler push build/web "$TARGET"
	echo "pushed to $TARGET. It goes live after itch.io processes it; check: butler status $TARGET"
else
	echo "not pushed (run tools/ship.sh --push when you want it live; the target is $TARGET)"
fi
