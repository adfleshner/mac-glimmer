#!/bin/bash
# Build Glimmer, install it to ~/Applications, and start it now and at every login.
#
#   ./scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

LABEL=com.adfleshner.glimmer
DEST="$HOME/Applications/Glimmer.app"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_=$(id -u)

./scripts/build.sh

echo "• Installing to $DEST"
launchctl bootout "gui/$UID_/$LABEL" 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/Library/LaunchAgents"
rm -rf "$DEST"
cp -R build/Glimmer.app "$DEST"

echo "• Starting at login ($AGENT)"
cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$DEST/Contents/MacOS/Glimmer</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict></plist>
EOF
launchctl bootstrap "gui/$UID_" "$AGENT"

echo "✓ Glimmer is running — look for the ☀︎ in your menu bar."
echo "  If it shows \"Enable brightness keys…\", click it and allow Glimmer in"
echo "  System Settings → Privacy & Security → Accessibility."
