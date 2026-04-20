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

