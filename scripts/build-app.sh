#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/PMT.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp "$ROOT_DIR/.build/release/PMT" "$MACOS_DIR/PMT"
chmod +x "$MACOS_DIR/PMT"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>PMT</string>
  <key>CFBundleIdentifier</key>
  <string>dev.pmt.PMT</string>
  <key>CFBundleName</key>
  <string>PMT</string>
  <key>CFBundleDisplayName</key>
  <string>PMT</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSInputMonitoringUsageDescription</key>
  <string>PMT needs Input Monitoring to detect the global rewrite hotkey while another app is focused.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>PMT activates the previous app so selected text can be copied and replaced in place.</string>
  <key>NSHumanReadableCopyright</key>
  <string>Open source.</string>
</dict>
</plist>
PLIST

echo "$APP_DIR"
