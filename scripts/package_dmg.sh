#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LocalPaste"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

WORK_DIR="$DIST_DIR/.dmg-work"
STAGE_DIR="$WORK_DIR/stage"
TEMP_DMG="$WORK_DIR/${APP_NAME}-temp.dmg"
VOLUME_NAME="$APP_NAME"

cd "$ROOT_DIR"

# 1) Build the .app bundle first.
"$ROOT_DIR/scripts/package_app.sh"

if [ ! -d "$APP_PATH" ]; then
    echo "App bundle not found: $APP_PATH"
    exit 1
fi

# 2) Prepare staging folder for DMG layout.
rm -rf "$WORK_DIR" "$DMG_PATH"
mkdir -p "$STAGE_DIR"

cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

# 3) Create compressed DMG.
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDRW \
    "$TEMP_DMG" >/dev/null

hdiutil convert \
    "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" >/dev/null

rm -rf "$WORK_DIR"

echo "Built dmg: $DMG_PATH"
