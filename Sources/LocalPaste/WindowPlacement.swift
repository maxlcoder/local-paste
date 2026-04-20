import AppKit
import SwiftUI

extension Notification.Name {
    static let historyWindowPositionDidChange = Notification.Name("LocalPaste.HistoryWindowPositionDidChange")
    static let historyWindowWillShow = Notification.Name("LocalPaste.HistoryWindowWillShow")
    static let historyWindowDidHide = Notification.Name("LocalPaste.HistoryWindowDidHide")
}

enum HistoryWindowPosition: String, CaseIterable, Identifiable {
    case bottom
    case top
    case left
    case right

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .bottom: return "menu.popup_position.bottom"
        case .top: return "menu.popup_position.top"
        case .left: return "menu.popup_position.left"
        case .right: return "menu.popup_position.right"
        }
    }
}

private let historyWindowPositionStorageKey = "LocalPaste.HistoryWindowPosition"

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
                context.coordinator.attach(to: window)
                onResolve(window)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, NSWindowDelegate {
        private weak var observedWindow: NSWindow?
        private var isProgrammaticClose = false

        func attach(to window: NSWindow) {
            guard observedWindow !== window else { return }
            observedWindow?.delegate = nil
            observedWindow = window
            window.delegate = self
        }

        func windowDidResignKey(_ notification: Notification) {
            guard !isProgrammaticClose else { return }
            guard let window = observedWindow, window.identifier?.rawValue == "historyWindow" else { return }
            guard window.isVisible else { return }

            isProgrammaticClose = true
            hideHistoryWindow()
            DispatchQueue.main.async {
                self.isProgrammaticClose = false
            }
        }

        func windowWillClose(_ notification: Notification) {
            hideAppFromDock()
        }
    }
}

func currentHistoryWindowPosition() -> HistoryWindowPosition {
    let raw = UserDefaults.standard.string(forKey: historyWindowPositionStorageKey) ?? HistoryWindowPosition.bottom.rawValue
    return HistoryWindowPosition(rawValue: raw) ?? .bottom
}

func setHistoryWindowPosition(_ position: HistoryWindowPosition) {
    UserDefaults.standard.set(position.rawValue, forKey: historyWindowPositionStorageKey)
    NotificationCenter.default.post(name: .historyWindowPositionDidChange, object: nil)
}

@MainActor
func positionWindowAtScreenBottom(_ window: NSWindow) {
    let preferredPosition = currentHistoryWindowPosition()
    guard let screen = popupTargetScreen(for: window) else { return }

    window.identifier = NSUserInterfaceItemIdentifier("historyWindow")
    window.isMovable = false
    window.isMovableByWindowBackground = false
    window.styleMask.remove(.resizable)
    configureHistoryWindowAppearance(window)

    let visible = screen.visibleFrame
    var frame = window.frame

    let edgeInset: CGFloat = 8
    let fullWidth = max(420, visible.width - edgeInset * 2)
    let fullHeight = max(260, visible.height - edgeInset * 2)

    let sideWidth: CGFloat = 224
    let horizontalHeight: CGFloat = 280

    switch preferredPosition {
    case .bottom:
        frame.size.width = fullWidth
        frame.size.height = min(horizontalHeight, visible.height - edgeInset * 2)
        frame.origin.x = visible.minX + edgeInset
        frame.origin.y = visible.minY + edgeInset
    case .top:
        frame.size.width = fullWidth
        frame.size.height = min(horizontalHeight, visible.height - edgeInset * 2)
        frame.origin.x = visible.minX + edgeInset
        frame.origin.y = visible.maxY - frame.height - edgeInset
    case .left:
        frame.size.width = sideWidth
        frame.size.height = fullHeight
        frame.origin.x = visible.minX + edgeInset
        frame.origin.y = visible.minY + edgeInset
    case .right:
        frame.size.width = sideWidth
        frame.size.height = fullHeight
        frame.origin.x = visible.maxX - frame.width - edgeInset
        frame.origin.y = visible.minY + edgeInset
    }

    frame.origin.x = max(visible.minX + edgeInset, min(frame.origin.x, visible.maxX - frame.width - edgeInset))
    frame.origin.y = max(visible.minY + edgeInset, min(frame.origin.y, visible.maxY - frame.height - edgeInset))

    window.setFrame(frame, display: true, animate: false)
}

@MainActor
private func popupTargetScreen(for window: NSWindow) -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
        return mouseScreen
    }
    return window.screen ?? NSScreen.main
}

@MainActor
private func configureHistoryWindowAppearance(_ window: NSWindow) {
    window.styleMask.insert(.fullSizeContentView)
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.title = ""
    window.collectionBehavior.insert(.moveToActiveSpace)
    window.collectionBehavior.insert(.fullScreenAuxiliary)
    window.collectionBehavior.remove(.canJoinAllSpaces)
    window.toolbar = nil
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
    if #available(macOS 15.0, *) {
        window.titlebarSeparatorStyle = .none
    }
}

@MainActor
func repositionVisibleHistoryWindow() {
    guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "historyWindow" }) else {
        return
    }
    positionWindowAtScreenBottom(window)
}

@MainActor
func hideHistoryWindow() {
    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "historyWindow" }) {
        window.orderOut(nil)
    }
    NotificationCenter.default.post(name: .historyWindowDidHide, object: nil)
    hideAppFromDock()
}

@MainActor
func activateHistoryWindow() {
    hideAppFromDock()
    NSApp.activate(ignoringOtherApps: true)

    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "historyWindow" }) {
        positionWindowAtScreenBottom(window)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NotificationCenter.default.post(name: .historyWindowWillShow, object: nil)
        return
    }

    if let firstWindow = NSApp.windows.first {
        positionWindowAtScreenBottom(firstWindow)
        firstWindow.makeKeyAndOrderFront(nil)
        firstWindow.orderFrontRegardless()
        NotificationCenter.default.post(name: .historyWindowWillShow, object: nil)
    }
}

@MainActor
func hideAppFromDock() {
    NSApp.setActivationPolicy(.accessory)
}
