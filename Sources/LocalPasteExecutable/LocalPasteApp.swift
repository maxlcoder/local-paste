import AppKit
import LocalPasteUI
import SwiftUI

@main
struct LocalPasteApp: App {
    @StateObject private var store = ClipboardStore()
    @StateObject private var hotkeyManager = GlobalHotkeyManager()

    init() {
        enforceSingleInstanceLaunch()
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        WindowGroup("LocalPaste", id: "history") {
            ContentView(store: store, hotkeyManager: hotkeyManager)
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("LocalPaste", systemImage: "clipboard") {
            MenuBarHistoryView(store: store, hotkeyManager: hotkeyManager)
        }
        .menuBarExtraStyle(.window)
    }

    private func enforceSingleInstanceLaunch() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let existingApps = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != currentPID }

        guard let existing = existingApps.first else { return }

        existing.unhide()
        existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }
}
