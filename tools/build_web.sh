#!/bin/sh
# Export the web build and add the website's extras: the start-screen and
# link-preview images and licenses.txt. Also zips it for itch.io.
# Usage: sh tools/build_web.sh
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
rm -rf build/web
mkdir -p build/web
# Godot's export progress is long; keep it in a log and show it only on failure.
"$GODOT" --headless --path . --export-release "Web" build/web/index.html > build/export.log 2>&1 || { cat build/export.log; exit 1; }
"$GODOT" --headless --path . --script tools/dump_licenses.gd > /dev/null
cp web/title.png web/og.png build/web/
rm -f build/super-rex-live-web.zip
(cd build/web && zip -qr ../super-rex-live-web.zip .)
echo "web build ready in build/web ($(du -sh build/web | cut -f1)), itch.io zip at build/super-rex-live-web.zip"
