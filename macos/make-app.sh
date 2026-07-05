#!/usr/bin/env bash
# Build a double-clickable macOS .app bundle wrapping the icqq-app CLI binary.
#
# icqq-app is an interactive console app (QR scan, live logs), so a bare .app
# executable (which runs with no TTY) is useless — instead the bundle's launcher
# opens Terminal.app, cd's to the folder that CONTAINS the .app (where the user
# keeps config.yaml + data/), and runs the real binary there.
#
# Usage: make-app.sh <path-to-icqq-app-binary> <output-app-dir> <version>
set -euo pipefail

BIN_SRC="$1"
APP="$2"
VER="$3"

mkdir -p "$APP/Contents/MacOS"

# The real Rust binary lives inside the bundle; advanced users can still run it
# directly from Terminal (Contents/MacOS/icqq-app-bin).
cp "$BIN_SRC" "$APP/Contents/MacOS/icqq-app-bin"
chmod +x "$APP/Contents/MacOS/icqq-app-bin"

# CFBundleExecutable — the launcher that runs on double-click.
cat > "$APP/Contents/MacOS/icqq-onebot" <<'LAUNCH'
#!/bin/bash
# On double-click, open Terminal in the folder CONTAINING the .app (put your
# config.yaml + data/ there) and run the real binary in it.
BUNDLE="$(cd "$(dirname "$0")/../.." && pwd)"   # …/icqq-onebot.app
WORK="$(dirname "$BUNDLE")"                       # folder that holds the .app
BIN="$(cd "$(dirname "$0")" && pwd)/icqq-app-bin"
# best-effort: strip the download quarantine so Gatekeeper doesn't block the child
xattr -dr com.apple.quarantine "$BUNDLE" 2>/dev/null || true
osascript \
  -e 'tell application "Terminal" to activate' \
  -e "tell application \"Terminal\" to do script \"cd \\\"$WORK\\\" && \\\"$BIN\\\"\""
LAUNCH
chmod +x "$APP/Contents/MacOS/icqq-onebot"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>icqq-onebot</string>
  <key>CFBundleDisplayName</key><string>icqq-onebot</string>
  <key>CFBundleIdentifier</key><string>com.icqqjs.icqq-onebot</string>
  <key>CFBundleVersion</key><string>${VER}</string>
  <key>CFBundleShortVersionString</key><string>${VER}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>icqq-onebot</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>10.13</string>
</dict>
</plist>
PLIST

echo "built $APP (version $VER)"
