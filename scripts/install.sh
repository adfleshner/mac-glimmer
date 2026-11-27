#!/bin/bash
# Build Glimmer from source, install it to ~/Applications and open it.
# Glimmer adds itself to Login Items on first launch (toggle: "Open at login" in its panel).
#
#   ./scripts/install.sh
#
# Prefer not to build? Download Glimmer.dmg from the Releases page and drag it to Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

DEST="$HOME/Applications/Glimmer.app"
OLD_AGENT="$HOME/Library/LaunchAgents/com.adfleshner.glimmer.plist"

./scripts/build.sh

# Stop a running copy (and remove the launch agent older versions used).
launchctl bootout "gui/$(id -u)/com.adfleshner.glimmer" 2>/dev/null || true
rm -f "$OLD_AGENT"
pkill -x Glimmer 2>/dev/null || true
sleep 1

echo "• Installing to $DEST"
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
cp -R build/Glimmer.app "$DEST"
open "$DEST"

echo "✓ Glimmer is running — look for the ☀︎ in your menu bar. It opens at every login."
echo "  If it shows \"Enable brightness keys…\", click it and allow Glimmer in"
echo "  System Settings → Privacy & Security → Accessibility."
