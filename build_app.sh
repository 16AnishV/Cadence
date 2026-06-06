#!/usr/bin/env bash
# Build Cadence and wrap the binary in a macOS .app bundle.
# Usage:
#   ./build_app.sh           # debug build, output: ./Cadence.app
#   ./build_app.sh release   # release build
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

cd "$ROOT"
echo "==> swift build (--configuration $CONFIG)"
swift build --configuration "$CONFIG"

BIN_DIR="$(swift build --configuration "$CONFIG" --show-bin-path)"
BIN="$BIN_DIR/Cadence"

if [[ ! -x "$BIN" ]]; then
  echo "Could not find Cadence binary at $BIN" >&2
  exit 1
fi

APP="$ROOT/Cadence.app"
echo "==> bundling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/Cadence"

# App icon: build .icns if missing, then copy into Resources.
ICNS="$ROOT/Cadence/Resources/AppIcon.icns"
if [[ ! -f "$ICNS" ]]; then
  echo "==> building $ICNS"
  "$ROOT/build_icon.sh"
fi
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Cadence</string>
    <key>CFBundleDisplayName</key>
    <string>Cadence</string>
    <key>CFBundleIdentifier</key>
    <string>com.anish.cadence</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Cadence</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSUserNotificationAlertStyle</key>
    <string>banner</string>
</dict>
</plist>
PLIST

# Codesign with ad-hoc signature so launch-at-login + notifications behave better.
echo "==> ad-hoc codesigning"
codesign --force --deep --sign - "$APP" || true

echo "==> done: $APP"
echo "Open with: open '$APP'"
