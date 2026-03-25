import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}

@MainActor
private var positionedWindowNumbers: Set<Int> = []

@MainActor
func positionWindowAtScreenBottom(_ window: NSWindow) {
    guard !positionedWindowNumbers.contains(window.windowNumber) else { return }
    guard let screen = window.screen ?? NSScreen.main else { return }

    positionedWindowNumbers.insert(window.windowNumber)
    window.identifier = NSUserInterfaceItemIdentifier("historyWindow")

    let visible = screen.visibleFrame
    var frame = window.frame

    let targetWidth = min(max(1020, frame.width), visible.width - 24)
    let targetHeight = min(max(320, frame.height), visible.height * 0.55)

    frame.size.width = targetWidth
    frame.size.height = targetHeight
    frame.origin.x = visible.midX - targetWidth / 2
    frame.origin.y = visible.minY + 16

    window.setFrame(frame, display: true, animate: false)
}

@MainActor
func activateHistoryWindow() {
    NSApp.activate(ignoringOtherApps: true)

    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "historyWindow" }) {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        return
    }

    if let firstWindow = NSApp.windows.first {
        firstWindow.makeKeyAndOrderFront(nil)
        firstWindow.orderFrontRegardless()
    }
}
