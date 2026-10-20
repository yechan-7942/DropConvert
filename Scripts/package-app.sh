#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP_NAME="DropConvert"
APP_DIR="$PROJECT_ROOT/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$PROJECT_ROOT"
swift build -c release --product "$APP_NAME"
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$RESOURCES_DIR" "$MACOS_DIR"
cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>DropConvert</string>
  <key>CFBundleExecutable</key>
  <string>DropConvert</string>
  <key>CFBundleIdentifier</key>
  <string>com.yechan7942.dropconvert</string>
  <key>CFBundleName</key>
  <string>DropConvert</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

chmod 755 "$MACOS_DIR/$APP_NAME"
codesign --force --deep --sign - "$APP_DIR" >/dev/null
printf 'Created %s\n' "$APP_DIR"
