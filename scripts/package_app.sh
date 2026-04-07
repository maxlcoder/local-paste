#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LocalPaste"
BUNDLE_ID="com.localpaste.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
BUILD_ARCHS="${BUILD_ARCHS:-arm64 x86_64}"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_FILE="$ROOT_DIR/assets/LocalPaste.icns"

cd "$ROOT_DIR"

read -r -a ARCH_LIST <<< "$BUILD_ARCHS"
if [ "${#ARCH_LIST[@]}" -eq 0 ]; then
    echo "No build architectures provided."
    exit 1
fi

for arch in "${ARCH_LIST[@]}"; do
    swift build -c release --arch "$arch"
done

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

BINARIES=()
for arch in "${ARCH_LIST[@]}"; do
    arch_binary="$ROOT_DIR/.build/${arch}-apple-macosx/release/$APP_NAME"
    if [ ! -f "$arch_binary" ]; then
        arch_binary="$ROOT_DIR/.build/release/$APP_NAME"
    fi
    if [ ! -f "$arch_binary" ]; then
        echo "Missing build output for $arch: $arch_binary"
        exit 1
    fi
    BINARIES+=("$arch_binary")
done

if [ "${#BINARIES[@]}" -eq 1 ]; then
    cp "${BINARIES[0]}" "$MACOS_DIR/$APP_NAME"
else
    lipo -create "${BINARIES[@]}" -output "$MACOS_DIR/$APP_NAME"
fi

chmod +x "$MACOS_DIR/$APP_NAME"

if [ -f "$ICON_FILE" ]; then
    cp "$ICON_FILE" "$RESOURCES_DIR/LocalPaste.icns"
fi

PRIMARY_ARCH="${ARCH_LIST[0]}"
PRIMARY_RELEASE_DIR="$ROOT_DIR/.build/${PRIMARY_ARCH}-apple-macosx/release"
if [ ! -d "$PRIMARY_RELEASE_DIR" ]; then
    PRIMARY_RELEASE_DIR="$ROOT_DIR/.build/release"
fi

while IFS= read -r bundle_path; do
    cp -R "$bundle_path" "$RESOURCES_DIR/"
done < <(find "$PRIMARY_RELEASE_DIR" -maxdepth 1 -name "*.bundle" -type d)

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>LocalPaste</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSRequiresNativeExecution</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --deep --sign - "$APP_DIR"
else
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

codesign --verify --deep --strict "$APP_DIR"

echo "Built app bundle: $APP_DIR"
