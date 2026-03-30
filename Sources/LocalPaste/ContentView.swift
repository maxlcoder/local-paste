import AppKit
import SwiftUI

struct ContentView: View {
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
            return EdgeInsets(top: 6, leading: 10, bottom: 10, trailing: 10)
        }
        return EdgeInsets(top: 6, leading: 12, bottom: 14, trailing: 12)
    }

    private var topBarLeadingInset: CGFloat {
        useVerticalCardsLayout ? 74 : 88
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(alignment: .leading, spacing: 14) {
                topBar
                cardsBoard
            }
            .padding(outerPadding)
        }
        .frame(
            minWidth: useVerticalCardsLayout ? 224 : 1080,
            idealWidth: contentWidth,
            maxWidth: useVerticalCardsLayout ? 224 : .infinity,
            minHeight: 340,
            idealHeight: 380
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
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.95, blue: 0.91),
                    Color(red: 0.92, green: 0.94, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.96, green: 0.68, blue: 0.16).opacity(0.20))
                .frame(width: 420, height: 420)
                .offset(x: 420, y: -180)

            Circle()
                .fill(Color(red: 0.15, green: 0.66, blue: 0.91).opacity(0.14))
                .frame(width: 380, height: 380)
                .offset(x: -440, y: 160)
        }
    }

    private var topBar: some View {
        Group {
            if useVerticalCardsLayout {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("LocalPaste")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer(minLength: 4)
                        Text(L10n.tr("content.items_count", store.items.count))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
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
                HStack(spacing: 10) {
                    Text("LocalPaste")
                        .font(.system(size: 15, weight: .bold, design: .rounded))

                    categoryChip(text: L10n.tr("content.category_all"), active: true)
                    categoryChip(text: L10n.tr("content.category_mix"), active: false)

                    searchField

                    Spacer(minLength: 6)

                    Text(L10n.tr("content.items_count", store.items.count))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

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
                }
                .frame(height: 30)
            }
        }
        .padding(.leading, topBarLeadingInset)
        .padding(.trailing, useVerticalCardsLayout ? 0 : 2)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(L10n.tr("content.search_placeholder"), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: useVerticalCardsLayout ? .infinity : 220)
        .background(.thinMaterial, in: Capsule())
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
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .center) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.46), lineWidth: 1)
        }
    }

    private func categoryChip(text: String, active: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(active ? Color.black.opacity(0.78) : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(active ? Color.white.opacity(0.82) : Color.white.opacity(0.45))
            )
    }

    private func actionButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 22)
                .background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        let palette: [Color] = [
            Color(red: 0.96, green: 0.37, blue: 0.40),
            Color(red: 0.17, green: 0.67, blue: 0.93),
            Color(red: 0.97, green: 0.75, blue: 0.12),
            Color(red: 0.31, green: 0.79, blue: 0.44),
            Color(red: 0.95, green: 0.54, blue: 0.17)
        ]

        let seed = item.kind == .text ? previewText.hashValue : (item.imageHash ?? "image").hashValue
        return palette[abs(seed) % palette.count]
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
                        .foregroundStyle(Color.black.opacity(0.46))
                } else {
                    Text(previewText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .lineLimit(7)

                    Spacer(minLength: 0)

                    Text(L10n.tr("card.characters", (item.text ?? "").count))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.46))
                }
            }
            .padding(12)
            .frame(width: cardWidth, height: 188, alignment: .topLeading)
            .background(Color.white.opacity(0.92))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 11, x: 0, y: 5)
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
@MainActor
private enum PreviewSeed {
    static let defaultItems: [ClipboardItem] = [
        ClipboardItem(
            text: "2026-03-16 ~ 2026-03-20 刘仁麟周报",
            copiedAt: Date().addingTimeInterval(-90)
        ),
        ClipboardItem(
            text: "2. 惠农直通车推送 IRS 数据中空格问题处理",
            copiedAt: Date().addingTimeInterval(-7200)
        ),
        ClipboardItem(
            imageFileName: "preview-image.png",
            imageWidth: 1645,
            imageHeight: 471,
            imageHash: "preview-image-hash",
            copiedAt: Date().addingTimeInterval(-172800)
        ),
        ClipboardItem(
            text: "Translated Report (Full Report Below)\n\nProcess: LocalPaste\nPath: /Users/USER/*/LocalPaste.app/Contents/MacOS/LocalPaste",
            copiedAt: Date().addingTimeInterval(-320000)
        )
    ]

    static let previewHotkey = HotkeyConfiguration(
        keyCode: 9,
        command: true,
        option: false,
        control: false,
        shift: true
    )
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(
                store: .preview(items: PreviewSeed.defaultItems, clickAction: .copyOnly),
                hotkeyManager: .preview(configuration: PreviewSeed.previewHotkey)
            )
            .previewDisplayName("Horizontal")
            .frame(width: 1180, height: 380)

            ContentView(
                store: .preview(items: PreviewSeed.defaultItems, clickAction: .copyAndAutoPaste),
                hotkeyManager: .preview(configuration: PreviewSeed.previewHotkey)
            )
            .previewDisplayName("Vertical")
            .frame(width: 224, height: 700)
        }
    }
}
#endif
