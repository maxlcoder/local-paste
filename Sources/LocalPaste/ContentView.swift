import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.openWindow) private var openWindow
    @State private var query = ""

    private var filteredItems: [ClipboardItem] {
        if query.isEmpty {
            return store.items
        }

        return store.items.filter {
            $0.searchableText.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(alignment: .leading, spacing: 14) {
                topBar
                cardsBoard
            }
            .padding(16)
        }
        .frame(minWidth: 1080, idealWidth: 1240, minHeight: 340, idealHeight: 380)
        .background(WindowAccessor { window in
            positionWindowAtScreenBottom(window)
        })
        .onAppear {
            hotkeyManager.onTriggered = { [openWindow] in
                Task { @MainActor in
                    store.capturePotentialPasteTarget()
                    toggleHistoryWindow(openWindow: openWindow)
                }
            }
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
        .frame(maxWidth: 220)
        .background(.thinMaterial, in: Capsule())
    }

    private var cardsBoard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 10) {
                Circle().fill(Color(red: 0.95, green: 0.34, blue: 0.38)).frame(width: 8, height: 8)
                Circle().fill(Color(red: 0.17, green: 0.67, blue: 0.93)).frame(width: 8, height: 8)
                Circle().fill(Color(red: 0.97, green: 0.75, blue: 0.12)).frame(width: 8, height: 8)
                Spacer()
            }
            .frame(width: 26)
            .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(filteredItems) { item in
                        ClipboardCard(item: item, previewImage: store.image(for: item)) {
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
            .overlay {
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
        .padding(.leading, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.46), lineWidth: 1)
        )
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
            historyWindow.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            historyWindow.makeKeyAndOrderFront(nil)
            historyWindow.orderFrontRegardless()
        }
    }

    @MainActor
    private func closeHistoryWindow() {
        if let historyWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "historyWindow" }) {
            historyWindow.orderOut(nil)
        }
    }

    @MainActor
    private func isHistoryWindowFrontmost(_ historyWindow: NSWindow) -> Bool {
        NSApp.isActive && (historyWindow.isKeyWindow || historyWindow.isMainWindow)
    }
}

private struct ClipboardCard: View {
    let item: ClipboardItem
    let previewImage: NSImage?
    let onCopy: () -> Void
    let onDelete: () -> Void

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
                            .frame(width: 224, height: 118)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.07))
                            .frame(width: 224, height: 118)
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
            .frame(width: 248, height: 188, alignment: .topLeading)
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
