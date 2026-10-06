#!/bin/bash
# Builds OneNotePlainCopy.app into ~/Applications and starts it at login via a LaunchAgent.
# Uninstall: ./install.sh --uninstall
set -euo pipefail
cd "$(dirname "$0")"

NAME=OneNotePlainCopy
ID=local.onenote-plain-copy
APP="$HOME/Applications/$NAME.app"
AGENT="$HOME/Library/LaunchAgents/$ID.plist"
LOG="$HOME/Library/Logs/$NAME.log"

launchctl bootout "gui/$UID/$ID" 2>/dev/null || true
# A rebuild changes the ad-hoc signature, which voids the old Accessibility grant; drop it so macOS asks again.
tccutil reset Accessibility "$ID" >/dev/null 2>&1 || true

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -rf "$APP" "$AGENT"
  echo "Uninstalled."
  exit 0
fi

mkdir -p "$APP/Contents/MacOS" "$HOME/Library/LaunchAgents"
swiftc -O main.swift -o "$APP/Contents/MacOS/$NAME"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$ID</string>
  <key>CFBundleName</key><string>OneNote Plain Copy</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"

cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$ID</string>
  <key>ProgramArguments</key><array><string>$APP/Contents/MacOS/$NAME</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
launchctl bootstrap "gui/$UID" "$AGENT"
echo "Installed $APP (log: $LOG)"
