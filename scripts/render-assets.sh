#!/bin/bash
# Re-render the app icon and the README screenshots from the real SwiftUI views.
#
#   ./scripts/render-assets.sh
#
# Writes Resources/AppIcon.icns, docs/images/icon.png, hero.png, panel-dark.png,
# panel-light.png and panel.gif. Run it after changing the panel or the icon.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "• Compiling renderer"
swiftc -O -framework Cocoa -framework SwiftUI -framework IOKit -o "$TMP/glimmer" Sources/*.swift
"$TMP/glimmer" --render-assets "$TMP/out"

mkdir -p docs/images Resources
iconutil -c icns "$TMP/out/AppIcon.iconset" -o Resources/AppIcon.icns
cp "$TMP/out/icon-1024.png" docs/images/icon.png
cp "$TMP/out/hero.png" "$TMP/out/panel-dark.png" "$TMP/out/panel-light.png" "$TMP/out/panel.gif" docs/images/
echo "✓ Assets written to Resources/ and docs/images/"
ls -lh docs/images Resources/AppIcon.icns
