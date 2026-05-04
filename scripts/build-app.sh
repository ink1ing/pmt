#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/PMT.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

PMT_VERSION="${PMT_VERSION:-0.0.20}"
PMT_BUILD="${PMT_BUILD:-20}"
PMT_APPCAST_URL="${PMT_APPCAST_URL:-https://raw.githubusercontent.com/ink1ing/pmt/main/appcast.xml}"
PMT_SPARKLE_PUBLIC_KEY="${PMT_SPARKLE_PUBLIC_KEY:-hhzAtydrywj71r1bOKpOWDEAe4dn/+LO+ZUv5PK14Ew=}"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/PMT" "$MACOS_DIR/PMT"
chmod +x "$MACOS_DIR/PMT"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/PMT" 2>/dev/null || true

if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
  cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

SPARKLE_FRAMEWORK="$ROOT_DIR/.build/release/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
  ditto "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/Sparkle.framework"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
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
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${PMT_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${PMT_BUILD}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSInputMonitoringUsageDescription</key>
  <string>PMT needs Input Monitoring to detect the global rewrite hotkey while another app is focused.</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>PMT activates the previous app so selected text can be copied and replaced in place.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>PMT needs microphone access to record dictation when the preview dictation feature is enabled.</string>
  <key>SUEnableDownloader</key>
  <true/>
  <key>SUFeedURL</key>
  <string>${PMT_APPCAST_URL}</string>
  <key>SUPublicEDKey</key>
  <string>${PMT_SPARKLE_PUBLIC_KEY}</string>
  <key>NSHumanReadableCopyright</key>
  <string>Open source.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
