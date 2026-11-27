#!/bin/bash
# Build Glimmer and package it as a drag-to-Applications disk image in ./dist
#
#   ./scripts/make-dmg.sh
#
# Uses the same signing identity as build.sh (SIGN_IDENTITY, or an Apple Development /
# Developer ID certificate if one is installed). With a Developer ID you can also notarize:
#   xcrun notarytool submit dist/Glimmer-<version>.dmg --keychain-profile <profile> --wait
#   xcrun stapler staple dist/Glimmer-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
STAGE=build/dmg
DMG="dist/Glimmer-$VERSION.dmg"
rm -rf "$STAGE" && mkdir -p "$STAGE" dist
rm -f "$DMG"

cp -R build/Glimmer.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Read Me.txt" <<'EOF'
Glimmer — a glimmer of hope for every MacBook left in the dark.

INSTALL
1. Drag Glimmer onto the Applications folder.
2. Open Glimmer from Applications. Look for the ☀︎ in the menu bar.

IF MACOS SAYS GLIMMER "CAN'T BE OPENED" OR "CAN'T BE VERIFIED"
Glimmer is free and open source but isn't notarized by Apple.
Open System Settings → Privacy & Security, scroll down, and click "Open Anyway"
next to the Glimmer message. You only need to do this once.

BRIGHTNESS KEYS
If the ☀︎ panel shows "Enable brightness keys…", click it and switch Glimmer on in
System Settings → Privacy & Security → Accessibility.

Glimmer opens at login automatically; turn that off with "Open at login" in its panel.
To remove it: quit Glimmer from its panel and drag it to the Trash.

https://github.com/adfleshner/mac-glimmer
EOF

# Volume icon
cp Resources/AppIcon.icns "$STAGE/.VolumeIcon.icns"

echo "• Creating $DMG"
hdiutil create -quiet -volname "Glimmer" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG"

# Mark the volume as having a custom icon (needs a read-write pass).
if command -v SetFile >/dev/null 2>&1; then
  RW=build/rw.dmg
  hdiutil convert -quiet "$DMG" -format UDRW -o "$RW" -ov
  MNT=$(hdiutil attach -nobrowse -noverify -noautoopen "$RW" | tail -1 | awk -F'\t' '{print $NF}')
  SetFile -a C "$MNT" && SetFile -a V "$MNT/.VolumeIcon.icns" || true
  hdiutil detach -quiet "$MNT"
  rm -f "$DMG"
  hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG"
  rm -f "$RW"
fi

SIGN_IDENTITY=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -E '"(Developer ID Application|Apple Development):' | head -1 | awk '{print $2}' || true)}
if [ -n "$SIGN_IDENTITY" ]; then
  codesign --force --sign "$SIGN_IDENTITY" "$DMG"
fi

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"
