import AppKit
import SwiftUI

public struct ContentView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.openWindow) private var openWindow
    @State private var query = ""
    @State private var currentWindowPosition: HistoryWindowPosition = currentHistoryWindowPosition()

    private var filteredItems: [ClipboardItem] {
        if query.isEmpty {
            return store.items
        }

        return store.items.filter {
            $0.searchableText.localizedCaseInsensitiveContains(query)
        }
    }

    private var useVerticalCardsLayout: Bool {
        currentWindowPosition == .left || currentWindowPosition == .right
    }

    private var contentWidth: CGFloat {
        useVerticalCardsLayout ? 224 : 1240
    }

    private var outerPadding: EdgeInsets {
        if useVerticalCardsLayout {
            return EdgeInsets(top: 2, leading: 10, bottom: 6, trailing: 10)
        }
        return EdgeInsets(top: 2, leading: 14, bottom: 6, trailing: 14)
    }

    private var topCompensation: CGFloat {
        useVerticalCardsLayout ? 0 : 5
    }

    private var topBarLeadingInset: CGFloat {
        0
    }

    public init(store: ClipboardStore, hotkeyManager: GlobalHotkeyManager) {
        self.store = store
        self.hotkeyManager = hotkeyManager
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundLayer

            VStack(alignment: .leading, spacing: 14) {
                topBar
                cardsBoard
            }
            .padding(outerPadding)
            .ignoresSafeArea(.container, edges: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(y: topCompensation)
        }
        .frame(
            minWidth: useVerticalCardsLayout ? 224 : 1080,
            idealWidth: contentWidth,
            maxWidth: useVerticalCardsLayout ? 224 : .infinity,
            minHeight: useVerticalCardsLayout ? 300 : 280,
            idealHeight: useVerticalCardsLayout ? 340 : 240
        )
        .background(WindowAccessor { window in
            positionWindowAtScreenBottom(window)
        })
        .onAppear {
            currentWindowPosition = currentHistoryWindowPosition()
            hotkeyManager.onTriggered = { [openWindow] in
                Task { @MainActor in
                    store.capturePotentialPasteTarget()
                    toggleHistoryWindow(openWindow: openWindow)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .historyWindowPositionDidChange)) { _ in
            currentWindowPosition = currentHistoryWindowPosition()
        }
    }

    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: useVerticalCardsLayout ? 16 : 24, style: .continuous)
            .fill(Color(red: 0.02, green: 0.03, blue: 0.05))
            .overlay {
                RoundedRectangle(cornerRadius: useVerticalCardsLayout ? 16 : 24, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 8)
            .ignoresSafeArea()
    }

    private var topBar: some View {
        Group {
            if useVerticalCardsLayout {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("LocalPaste")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.80))
                        Spacer(minLength: 4)
                        Text(L10n.tr("content.items_count", store.items.count))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.56))
                    }

                    searchField

                    HStack(spacing: 6) {
                        actionButton("square.and.arrow.down", help: L10n.tr("content.help.import_txt")) {
                            store.importHistoryFromTXT()
                        }

                        actionButton("square.and.arrow.up", help: L10n.tr("content.help.export_txt")) {
                            store.exportHistoryAsTXT()
                        }
                        .disabled(store.items.isEmpty)

                        actionButton("trash", help: L10n.tr("content.help.clear")) {
                            store.clearAll()
                        }
                        .disabled(store.items.isEmpty)

                        Spacer(minLength: 0)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Text("LocalPaste")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.80))

                    Spacer(minLength: 10)

                    searchField

                    categoryChip(text: "剪贴板", active: true)

                    actionButton("plus", help: L10n.tr("content.help.import_txt")) {
                        store.importHistoryFromTXT()
                    }

                    actionButton("ellipsis", help: L10n.tr("content.help.export_txt")) {
                        store.exportHistoryAsTXT()
                    }
                    .disabled(store.items.isEmpty)

                    Spacer(minLength: 10)
                }
                .frame(height: 36)
            }
        }
        .padding(.leading, topBarLeadingInset)
        .padding(.trailing, useVerticalCardsLayout ? 0 : 2)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.60))

            TextField(L10n.tr("content.search_placeholder"), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.90))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: useVerticalCardsLayout ? .infinity : 280)
        .background(Color.white.opacity(0.12), in: Capsule())
    }

    private var cardsBoard: some View {
        Group {
            Group {
                if useVerticalCardsLayout {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(filteredItems) { item in
                                ClipboardCard(item: item, previewImage: store.image(for: item), isCompact: useVerticalCardsLayout) {
                                    store.performPrimaryAction(for: item)
                                    closeHistoryWindow()
                                } onDelete: {
                                    store.delete(item)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.trailing, 12)
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(filteredItems) { item in
                                ClipboardCard(item: item, previewImage: store.image(for: item), isCompact: useVerticalCardsLayout) {
                                    store.performPrimaryAction(for: item)
                                    closeHistoryWindow()
                                } onDelete: {
                                    store.delete(item)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.trailing, 12)
                    }
                }
            }
            .overlay(alignment: .center) {
                if filteredItems.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text(query.isEmpty ? L10n.tr("content.empty_history") : L10n.tr("content.no_search_result"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 0)
    }

    private func categoryChip(text: String, active: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(active ? Color.white.opacity(0.92) : Color.white.opacity(0.65))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(active ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
            )
    }

    private func actionButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 22)
                .foregroundStyle(Color.white.opacity(0.90))
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @MainActor
    private func toggleHistoryWindow(openWindow: OpenWindowAction) {
        guard let historyWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "historyWindow" }) else {
            openWindow(id: "history")
            activateHistoryWindow()
            return
        }

        guard historyWindow.isVisible else {
            historyWindow.makeKeyAndOrderFront(nil)
            activateHistoryWindow()
            return
        }

        if isHistoryWindowFrontmost(historyWindow) {
            hideHistoryWindow()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            historyWindow.makeKeyAndOrderFront(nil)
            historyWindow.orderFrontRegardless()
        }
    }

    @MainActor
    private func closeHistoryWindow() {
        hideHistoryWindow()
    }

    @MainActor
    private func isHistoryWindowFrontmost(_ historyWindow: NSWindow) -> Bool {
        NSApp.isActive && (historyWindow.isKeyWindow || historyWindow.isMainWindow)
    }
}

private struct ClipboardCard: View {
    let item: ClipboardItem
    let previewImage: NSImage?
    let isCompact: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    private var cardWidth: CGFloat {
        isCompact ? 180 : 248
    }

    private var imagePreviewWidth: CGFloat {
        isCompact ? 156 : 224
    }

    private var previewText: String {
        let normalized = (item.text ?? "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? L10n.tr("card.empty_text") : normalized
    }

    private var cardColor: Color {
        Color(red: 0.10, green: 0.60, blue: 0.86)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(item.kind == .text ? L10n.tr("card.type_text") : L10n.tr("card.type_image"))
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text(relativeDate)
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.86)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(cardColor)

            VStack(alignment: .leading, spacing: 8) {
                if item.kind == .image {
                    if let previewImage {
                        Image(nsImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: imagePreviewWidth, height: 118)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.07))
                            .frame(width: imagePreviewWidth, height: 118)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                    }

                    Text(L10n.tr("card.image_size", item.pixelDescription))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.58))
                } else {
                    Text(previewText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.90))
                        .lineLimit(7)

                    Spacer(minLength: 0)

                    Text(L10n.tr("card.characters", (item.text ?? "").count))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.56))
                }
            }
            .padding(12)
            .frame(width: cardWidth, height: 188, alignment: .topLeading)
            .background(Color(red: 0.05, green: 0.06, blue: 0.09))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.10, green: 0.60, blue: 0.86), lineWidth: 1.8)
        )
        .shadow(color: Color(red: 0.10, green: 0.60, blue: 0.86).opacity(0.24), radius: 12, x: 0, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: onCopy)
        .contextMenu {
            Button(L10n.tr("action.copy")) { onCopy() }
            Button(L10n.tr("action.delete")) { onDelete() }
        }
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: item.copiedAt, relativeTo: Date())
    }
}

#if DEBUG
private struct ClipboardCardPreviewScene: View {
    let item: ClipboardItem
    let isCompact: Bool

    var body: some View {
        ClipboardCard(
            item: item,
            previewImage: nil,
            isCompact: isCompact,
            onCopy: {},
            onDelete: {}
        )
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.97, green: 0.95, blue: 0.91), Color(red: 0.92, green: 0.94, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

#Preview("History Bottom") {
    ContentViewPreviewScene(
        position: .bottom,
        items: PreviewFixtures.defaultItems,
        clickAction: .copyOnly
    )
}

#Preview("History Right") {
    ContentViewPreviewScene(
        position: .right,
        items: PreviewFixtures.defaultItems,
        clickAction: .copyAndAutoPaste
    )
    .frame(width: 224, height: 700)
}

#Preview("History Empty") {
    ContentViewPreviewScene(
        position: .bottom,
        items: [],
        clickAction: .copyOnly
    )
    .frame(width: 1180, height: 380)
}

#Preview("Clipboard Card Text") {
    ClipboardCardPreviewScene(
        item: ClipboardItem(text: "模块预览：用于检查卡片文本样式、字重、行高和字符计数显示。"),
        isCompact: false
    )
    .frame(width: 320, height: 260)
}

#Preview("Clipboard Card Compact") {
    ClipboardCardPreviewScene(
        item: ClipboardItem(text: "侧边栏模式卡片"),
        isCompact: true
    )
    .frame(width: 240, height: 260)
}
#endif
