#!/bin/bash
# Stop Glimmer and remove it, its login item and its settings.
#
#   ./scripts/uninstall.sh
set -euo pipefail

LABEL=com.adfleshner.glimmer
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/Glimmer.app"
defaults delete "$LABEL" 2>/dev/null || true
tccutil reset Accessibility "$LABEL" >/dev/null 2>&1 || true
echo "✓ Glimmer removed. Screen colours are restored automatically when it quits."
