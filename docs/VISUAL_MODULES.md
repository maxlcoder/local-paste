# LocalPaste Visual Modules

This document describes the purpose of each visual module and where to preview it in Xcode Canvas.

## 1. ContentView
- File: `Sources/LocalPaste/ContentView.swift`
- Role: Main history panel. Shows top actions, search, and clipboard history cards.
- Key states:
  - Normal history list
  - Side panel (left/right) compact layout
  - Empty history placeholder
- Preview entries:
  - `History Bottom`
  - `History Right`
  - `History Empty`

## 2. ClipboardCard
- File: `Sources/LocalPaste/ContentView.swift` (private subview)
- Role: Single clipboard record card for text/image content.
- Key states:
  - Normal width card
  - Compact width card (side panel mode)
- Preview entries:
  - `Clipboard Card Text`
  - `Clipboard Card Compact`

## 3. MenuBarHistoryView
- File: `Sources/LocalPaste/MenuBarHistoryView.swift`
- Role: Menu bar popup settings surface (language, hotkey recording, copy rule, popup position, history actions).
- Preview entries:
  - `Menu Bar Settings`

## 4. HotkeySettingsView
- File: `Sources/LocalPaste/HotkeySettingsView.swift`
- Role: Standalone hotkey settings panel with shortcut recording and click-action behavior.
- Preview entries:
  - `Hotkey Settings`

## Preview Support
- File: `Sources/LocalPaste/PreviewSupport.swift`
- Role: Shared preview fixtures and helper scene to keep all visual previews deterministic and side-effect free.
- Includes:
  - Sample clipboard items
  - Sample hotkey configuration
  - `ContentViewPreviewScene` wrapper
