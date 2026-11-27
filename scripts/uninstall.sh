#!/bin/bash
# Stop Glimmer and remove it, its login item and its settings.
#
#   ./scripts/uninstall.sh
set -euo pipefail

LABEL=com.adfleshner.glimmer
for APP in "$HOME/Applications/Glimmer.app" "/Applications/Glimmer.app"; do
  if [ -x "$APP/Contents/MacOS/Glimmer" ]; then
    "$APP/Contents/MacOS/Glimmer" --unregister-login-item 2>/dev/null || true
  fi
done
pkill -x Glimmer 2>/dev/null || true
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true      # older versions
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/Glimmer.app"
[ -d /Applications/Glimmer.app ] && rm -rf /Applications/Glimmer.app 2>/dev/null || true
defaults delete "$LABEL" 2>/dev/null || true
tccutil reset Accessibility "$LABEL" >/dev/null 2>&1 || true
echo "✓ Glimmer removed. Screen colours are restored automatically when it quits."
