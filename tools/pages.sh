#!/usr/bin/env bash
# Builds the shipping web build (hub page plus every prototype) and copies it into docs/ for
# GitHub Pages (branch main, /docs). Never commits or pushes. Usage: tools/pages.sh
set -euo pipefail
cd "$(dirname "$0")/.."
tools/test.sh >/dev/null
rm -rf build/web
tools/build.sh --size
rm -rf docs
mkdir docs
cp -r build/web/. docs/
touch docs/.nojekyll
echo "docs/ ready ($(du -sh docs | cut -f1)); commit it and push to update https://playdeezgames.github.io/prototypes-of-splorr/"
