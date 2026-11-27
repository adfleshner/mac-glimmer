#!/bin/bash
# Build Glimmer.app (universal: Apple Silicon + Intel) into ./build
#
#   ./scripts/build.sh
#
# Signing: set SIGN_IDENTITY to a codesigning identity (see `security find-identity -v -p codesigning`).
# If unset, the first "Apple Development" / "Developer ID Application" identity is used,
# otherwise the app is ad-hoc signed. A real identity keeps the Accessibility permission
# across rebuilds; with ad-hoc signing you'll need to re-grant it after each rebuild.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Glimmer.app
MIN_OS=13.0
rm -rf build && mkdir -p "$APP/Contents/MacOS" build/obj

for arch in arm64 x86_64; do
  echo "• Compiling ($arch)"
  swiftc -O -target "$arch-apple-macos$MIN_OS" \
    -framework Cocoa -framework SwiftUI -framework IOKit \
    -o "build/obj/Glimmer-$arch" Sources/*.swift
done
lipo -create -output "$APP/Contents/MacOS/Glimmer" build/obj/Glimmer-arm64 build/obj/Glimmer-x86_64
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [ -z "${SIGN_IDENTITY:-}" ]; then
  SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -E '"(Apple Development|Developer ID Application):' | head -1 | awk '{print $2}' || true)
fi
if [ -n "${SIGN_IDENTITY:-}" ]; then
  echo "• Signing with $SIGN_IDENTITY"
  codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP"
else
  echo "• No signing identity found — ad-hoc signing"
  codesign --force --sign - "$APP"
fi

codesign --verify "$APP"
echo "✓ Built $APP ($(lipo -archs "$APP/Contents/MacOS/Glimmer"))"
