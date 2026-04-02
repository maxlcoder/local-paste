import ApplicationServices
import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

enum RecordClickAction: String, Codable, CaseIterable, Identifiable {
    case copyOnly
    case copyAndAutoPaste

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copyOnly:
            return L10n.tr("action.copy_only")
        case .copyAndAutoPaste:
            return L10n.tr("action.copy_to_app")
        }
    }
}

enum HistoryRetentionPolicy: String, Codable, CaseIterable, Identifiable {
    case forever
    case oneDay
    case threeDays
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forever:
            return L10n.tr("retention.forever")
        case .oneDay:
            return L10n.tr("retention.one_day")
        case .threeDays:
            return L10n.tr("retention.three_days")
        case .sevenDays:
            return L10n.tr("retention.seven_days")
        case .thirtyDays:
            return L10n.tr("retention.thirty_days")
        }
    }

    func cutoffDate(relativeTo now: Date) -> Date? {
        switch self {
        case .forever:
            return nil
        case .oneDay:
            return now.addingTimeInterval(-86_400)
        case .threeDays:
            return now.addingTimeInterval(-3 * 86_400)
        case .sevenDays:
            return now.addingTimeInterval(-7 * 86_400)
        case .thirtyDays:
            return now.addingTimeInterval(-30 * 86_400)
        }
    }
}

@MainActor
public final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var clickAction: RecordClickAction
    @Published private(set) var retentionPolicy: HistoryRetentionPolicy

    private let pasteboard = NSPasteboard.general
    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastExternalAppPID: pid_t?
    private var lastExternalBundleID: String?

    private let pollInterval: TimeInterval = 0.7
    private let exportSeparator = "\n\n-----LOCALPASTE-ITEM-----\n\n"
    private let clickActionStorageKey = "LocalPaste.RecordClickAction"
    private let retentionPolicyStorageKey = "LocalPaste.HistoryRetentionPolicy"

    public init(shouldStartMonitoring: Bool = true) {
        self.lastChangeCount = pasteboard.changeCount
        self.clickAction = Self.loadClickAction(key: clickActionStorageKey) ?? .copyOnly
        self.retentionPolicy = Self.loadRetentionPolicy(key: retentionPolicyStorageKey) ?? .forever
        if shouldStartMonitoring {
            loadHistory()
            captureCurrentFrontmostAppIfNeeded()
            captureCurrentPasteboardIfNeeded()
            startMonitoring()
        }
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.captureCurrentFrontmostAppIfNeeded()
                self?.purgeExpiredItemsIfNeeded()
                self?.pollPasteboard()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func copy(_ item: ClipboardItem, shouldPromote: Bool = true) {
        switch item.kind {
        case .text:
            guard let content = item.text else { return }
            pasteboard.clearContents()
            pasteboard.setString(content, forType: .string)
            lastChangeCount = pasteboard.changeCount
            if shouldPromote {
                addText(content)
            }

        case .image:
            guard let image = image(for: item) else {
                NSSound.beep()
                return
            }
            pasteboard.clearContents()
            pasteboard.writeObjects([image])
            lastChangeCount = pasteboard.changeCount
            if shouldPromote {
                addImage(image)
            }
        }
    }

    func promoteItemToFront(itemID: UUID) {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        switch item.kind {
        case .text:
            guard let text = item.text else { return }
            addText(text)
        case .image:
            guard let image = image(for: item) else { return }
            addImage(image)
        }
    }

    func image(for item: ClipboardItem) -> NSImage? {
        guard item.kind == .image, let fileName = item.imageFileName else { return nil }
        let fileURL = imageDirectoryURL().appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    func delete(_ item: ClipboardItem) {
        removeImageAssetIfNeeded(for: item)
        items.removeAll { $0.id == item.id }
        saveHistory()
    }

    func clearAll() {
        for item in items {
            removeImageAssetIfNeeded(for: item)
        }
        items.removeAll()
        saveHistory()
    }

    func updateClickAction(_ action: RecordClickAction) {
        clickAction = action
        UserDefaults.standard.set(action.rawValue, forKey: clickActionStorageKey)
    }

    func updateRetentionPolicy(_ policy: HistoryRetentionPolicy) {
        retentionPolicy = policy
        UserDefaults.standard.set(policy.rawValue, forKey: retentionPolicyStorageKey)
        purgeExpiredItemsIfNeeded()
    }

    func capturePotentialPasteTarget() {
        captureCurrentFrontmostAppIfNeeded()
    }

    func performPrimaryAction(for item: ClipboardItem) {
        copy(item)

        guard clickAction == .copyAndAutoPaste else { return }
        autoPasteIntoLastActiveApp()
    }

    func exportHistoryAsTXT() {
        let panel = NSSavePanel()
        panel.title = L10n.tr("store.panel.export_title")
        panel.nameFieldStringValue = defaultExportFileName()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let contents = items
            .compactMap { $0.kind == .text ? $0.text : nil }
            .joined(separator: exportSeparator)

        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSSound.beep()
        }
    }

    func importHistoryFromTXT() {
        let panel = NSOpenPanel()
        panel.title = L10n.tr("store.panel.import_title")
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let imported = parseImportedContents(content)

            guard !imported.isEmpty else { return }

            for item in imported.reversed() {
                addText(item)
            }
        } catch {
            NSSound.beep()
        }
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let image = readImageFromPasteboard() {
            addImage(image)
            return
        }

        if let text = readTextFromPasteboard() {
            addText(text)
        }
    }

    private func captureCurrentPasteboardIfNeeded() {
        if let image = readImageFromPasteboard() {
            addImage(image)
            return
        }

        if let text = readTextFromPasteboard() {
            addText(text)
        }
    }

    private func readTextFromPasteboard() -> String? {
        guard let current = pasteboard.string(forType: .string) else { return nil }
        let normalized = current.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func readImageFromPasteboard() -> NSImage? {
        guard pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) else { return nil }
        return pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
    }

    private func addText(_ content: String) {
        purgeExpiredItemsIfNeeded()

        if let existingIndex = items.firstIndex(where: { $0.kind == .text && $0.text == content }) {
            items.remove(at: existingIndex)
        }

        items.insert(ClipboardItem(text: content), at: 0)
        saveHistory()
    }

    private func addImage(_ image: NSImage) {
        purgeExpiredItemsIfNeeded()

        guard let pngData = image.pngData else { return }

        let hash = sha256Hex(pngData)
        let size = image.size

        if let existingIndex = items.firstIndex(where: {
            $0.kind == .image && $0.imageHash == hash
        }) {
            let existing = items.remove(at: existingIndex)
            if existing.imageFileName != nil {
                // Keep existing file and reuse it.
                items.insert(
                    ClipboardItem(
                        imageFileName: existing.imageFileName!,
                        imageWidth: Double(size.width),
                        imageHeight: Double(size.height),
                        imageHash: hash
                    ),
                    at: 0
                )
                saveHistory()
                return
            }
        }

        let fileName = "\(UUID().uuidString).png"
        let fileURL = imageDirectoryURL().appendingPathComponent(fileName)

        do {
            try pngData.write(to: fileURL, options: .atomic)

            items.insert(
                ClipboardItem(
                    imageFileName: fileName,
                    imageWidth: Double(size.width),
                    imageHeight: Double(size.height),
                    imageHash: hash
                ),
                at: 0
            )

            saveHistory()
        } catch {
            NSSound.beep()
        }
    }

    private func removeImageAssetIfNeeded(for item: ClipboardItem) {
        guard item.kind == .image, let fileName = item.imageFileName else { return }

        // If another record still references the same image file, do not delete it.
        let stillReferenced = items.contains { candidate in
            candidate.id != item.id && candidate.imageFileName == fileName
        }
        guard !stillReferenced else { return }

        let fileURL = imageDirectoryURL().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func storageURL() throws -> URL {
        let appFolder = appSupportFolderURL()
        return appFolder.appendingPathComponent("history.json")
    }

    private func imageDirectoryURL() -> URL {
        let appFolder = appSupportFolderURL()
        let imageFolder = appFolder.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
        return imageFolder
    }

    private func appSupportFolderURL() -> URL {
        let manager = FileManager.default
        let base = (try? manager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let appFolder = base.appendingPathComponent("LocalPaste", isDirectory: true)
        try? manager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder
    }

    private func loadHistory() {
        do {
            let url = try storageURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)

            items = decoded.filter { item in
                switch item.kind {
                case .text:
                    return !(item.text ?? "").isEmpty
                case .image:
                    guard let fileName = item.imageFileName else { return false }
                    let fileURL = imageDirectoryURL().appendingPathComponent(fileName)
                    return FileManager.default.fileExists(atPath: fileURL.path)
                }
            }

            purgeExpiredItemsIfNeeded(saveAfterPurge: false)
        } catch {
            items = []
        }
    }

    private func saveHistory() {
        do {
            let url = try storageURL()
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            // Ignore persistence failure to keep app responsive.
        }
    }

    private func parseImportedContents(_ content: String) -> [String] {
        if content.contains(exportSeparator) {
            return content
                .components(separatedBy: exportSeparator)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func defaultExportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "LocalPaste-History-\(formatter.string(from: Date())).txt"
    }

    private func captureCurrentFrontmostAppIfNeeded() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        rememberExternalApp(app)
    }

    private func rememberExternalApp(_ app: NSRunningApplication) {
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        lastExternalAppPID = app.processIdentifier
        lastExternalBundleID = app.bundleIdentifier
    }

    private func autoPasteIntoLastActiveApp() {
        guard ensureAccessibilityPermission() else {
            NSSound.beep()
            return
        }

        guard let targetApp = resolveTargetApp() else {
            NSSound.beep()
            return
        }

        let targetPID = targetApp.processIdentifier
        let targetBundleID = targetApp.bundleIdentifier
        targetApp.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        dispatchPasteShortcut(targetPID: targetPID, targetBundleID: targetBundleID, retry: 0)
    }

    private func resolveTargetApp() -> NSRunningApplication? {
        let currentBundleID = Bundle.main.bundleIdentifier
        let runningApps = NSWorkspace.shared.runningApplications

        if let lastExternalAppPID {
            if let app = runningApps.first(where: { $0.processIdentifier == lastExternalAppPID }) {
                if app.bundleIdentifier != currentBundleID {
                    return app
                }
            }
        }

        if let lastExternalBundleID {
            if let app = runningApps.first(where: { $0.bundleIdentifier == lastExternalBundleID }) {
                if app.bundleIdentifier != currentBundleID {
                    return app
                }
            }
        }

        if let frontmost = NSWorkspace.shared.frontmostApplication {
            if frontmost.bundleIdentifier != currentBundleID {
                return frontmost
            }
        }

        return nil
    }

    private func sendCommandV() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            NSSound.beep()
            return
        }

        let keyCodeForV: CGKeyCode = 9

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func dispatchPasteShortcut(targetPID: pid_t, targetBundleID: String?, retry: Int) {
        let delay: TimeInterval = retry == 0 ? 0.18 : 0.12

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let frontmost = NSWorkspace.shared.frontmostApplication
            let isExpectedTarget = frontmost?.processIdentifier == targetPID
                || (targetBundleID != nil && frontmost?.bundleIdentifier == targetBundleID)

            if isExpectedTarget {
                self.sendCommandV()
                return
            }

            guard retry < 3 else {
                NSSound.beep()
                return
            }

            if let target = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == targetPID }) {
                target.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            }

            self.dispatchPasteShortcut(targetPID: targetPID, targetBundleID: targetBundleID, retry: retry + 1)
        }
    }

    private func ensureAccessibilityPermission() -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        let options: CFDictionary = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return false
    }

    private static func loadClickAction(key: String) -> RecordClickAction? {
        guard let rawValue = UserDefaults.standard.string(forKey: key) else { return nil }
        return RecordClickAction(rawValue: rawValue)
    }

    private static func loadRetentionPolicy(key: String) -> HistoryRetentionPolicy? {
        guard let rawValue = UserDefaults.standard.string(forKey: key) else { return nil }
        return HistoryRetentionPolicy(rawValue: rawValue)
    }

    private func purgeExpiredItemsIfNeeded(saveAfterPurge: Bool = true) {
        guard let cutoffDate = retentionPolicy.cutoffDate(relativeTo: Date()) else { return }

        let expiredItems = items.filter { $0.copiedAt < cutoffDate }
        guard !expiredItems.isEmpty else { return }

        for item in expiredItems {
            removeImageAssetIfNeeded(for: item)
        }

        items.removeAll { $0.copiedAt < cutoffDate }
        if saveAfterPurge {
            saveHistory()
        }
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

#if DEBUG
@MainActor
extension ClipboardStore {
    static func preview(
        items: [ClipboardItem] = [],
        clickAction: RecordClickAction = .copyOnly
    ) -> ClipboardStore {
        let store = ClipboardStore(shouldStartMonitoring: false)
        store.items = items
        store.clickAction = clickAction
        return store
    }
}
#endif

private extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
