#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="LocalPaste"
DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"
APP_PATH="$DIST_DIR/${APP_NAME}.app"
GUIDE_PATH="$DIST_DIR/UNSIGNED_INSTALL.md"

cd "$ROOT_DIR"

# Build unsigned/ad-hoc package for internal testing distribution.
SIGN_IDENTITY="-" NOTARIZE=0 DMG_SIGN_IDENTITY="" "$ROOT_DIR/scripts/package_dmg.sh"

cat > "$GUIDE_PATH" <<'MD'
# LocalPaste (Unsigned Build) Install Guide

This package is unsigned/not notarized for external distribution.
On some macOS systems, Gatekeeper may block it with "damaged" or "cannot be opened" warnings.

## Install Steps

1. Open `LocalPaste.dmg`
2. Drag `LocalPaste.app` to `/Applications`
3. Run once in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/LocalPaste.app
```

4. Start app:

```bash
open /Applications/LocalPaste.app
```

## If still blocked

Use right click -> Open on `LocalPaste.app`, then confirm Open in the dialog.

MD

echo "Built unsigned dmg: $DMG_PATH"
echo "Install guide: $GUID_PATH"
