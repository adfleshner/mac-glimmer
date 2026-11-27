#!/bin/bash
# Re-render the app icon, the disk-image background and the README images from the real
# SwiftUI views.
#
#   ./scripts/render-assets.sh
#
# Writes Resources/AppIcon.icns, Resources/dmg-background.tiff and docs/images/
# (icon.png, hero.png, panel-dark.png, panel-light.png, panel.gif, download-button.png).
# Run it after changing the panel, the icon or the DMG artwork.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "• Compiling renderer"
swiftc -O -framework Cocoa -framework SwiftUI -framework IOKit -o "$TMP/glimmer" Sources/*.swift
"$TMP/glimmer" --render-assets "$TMP/out"

mkdir -p docs/images Resources
iconutil -c icns "$TMP/out/AppIcon.iconset" -o Resources/AppIcon.icns
# HiDPI background: 1x + 2x in one TIFF so the DMG window is sharp on Retina screens.
tiffutil -cathidpicheck "$TMP/out/dmg-background.png" "$TMP/out/dmg-background@2x.png" \
  -out Resources/dmg-background.tiff
cp "$TMP/out/icon-1024.png" docs/images/icon.png
cp "$TMP/out/dmg-window.png" docs/images/dmg-window.png
cp "$TMP/out/hero.png" "$TMP/out/panel-dark.png" "$TMP/out/panel-light.png" "$TMP/out/panel.gif" \
   "$TMP/out/download-button.png" "$TMP/out"/support-*.png docs/images/
echo "✓ Assets written to Resources/ and docs/images/"
ls -lh docs/images Resources/AppIcon.icns Resources/dmg-background.tiff
