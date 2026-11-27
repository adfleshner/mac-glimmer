#!/bin/bash
# Build Glimmer and package it as a polished drag-to-Applications disk image: dist/Glimmer.dmg
#
#   ./scripts/make-dmg.sh
#
# The window layout (background with arrow, icon positions, no toolbar) comes from
# scripts/dmg-settings.py and is written by dmgbuild (https://github.com/dmgbuild/dmgbuild),
# which is installed into ./.venv-dmg on first use. The file name has no version in it so
# https://github.com/adfleshner/mac-glimmer/releases/latest/download/Glimmer.dmg always works.
#
# Signing uses the same identity as build.sh. With a Developer ID you can also notarize:
#   xcrun notarytool submit dist/Glimmer.dmg --keychain-profile <profile> --wait
#   xcrun stapler staple dist/Glimmer.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh

# dmgbuild: use one already on PATH (CI installs it), else a private virtualenv.
if command -v dmgbuild >/dev/null 2>&1; then
  DMGBUILD=dmgbuild
else
  if [ ! -x .venv-dmg/bin/dmgbuild ]; then
    echo "• Installing dmgbuild into .venv-dmg"
    python3 -m venv .venv-dmg
    .venv-dmg/bin/pip install --quiet --disable-pip-version-check "dmgbuild>=1.6"
  fi
  DMGBUILD=.venv-dmg/bin/dmgbuild
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
DMG=dist/Glimmer.dmg
mkdir -p dist
rm -f "$DMG" "$DMG.sha256"

echo "• Creating $DMG (Glimmer $VERSION)"
"$DMGBUILD" -s scripts/dmg-settings.py -D app=build/Glimmer.app "Glimmer" "$DMG"

SIGN_IDENTITY=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -E '"(Developer ID Application|Apple Development):' | head -1 | awk '{print $2}' || true)}
if [ -n "$SIGN_IDENTITY" ]; then
  codesign --force --sign "$SIGN_IDENTITY" "$DMG"
fi

(cd dist && shasum -a 256 Glimmer.dmg | tee Glimmer.dmg.sha256)
echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"

# Don't leave a second Glimmer.app lying around: macOS could launch it at login instead of
# the one in Applications.
rm -rf build/Glimmer.app
