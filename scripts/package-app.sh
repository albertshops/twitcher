#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIGURATION=${CONFIGURATION:-release}
APP="$ROOT/dist/Twitcher.app"
CONTENTS="$APP/Contents"

swift build --package-path "$ROOT" -c "$CONFIGURATION"
BIN_DIR=$(swift build --package-path "$ROOT" -c "$CONFIGURATION" --show-bin-path)

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/Twitcher" "$CONTENTS/MacOS/Twitcher"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Twitcher</string>
    <key>CFBundleIdentifier</key>
    <string>dev.twitcher.app</string>
    <key>CFBundleName</key>
    <string>Twitcher</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026</string>
</dict>
</plist>
PLIST

codesign \
    --force \
    --sign - \
    --requirements '=designated => identifier "dev.twitcher.app"' \
    "$APP"
echo "$APP"
