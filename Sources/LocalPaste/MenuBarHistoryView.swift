import AppKit
import SwiftUI

public struct MenuBarHistoryView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.openWindow) private var openWindow

    @State private var draftConfiguration: HotkeyConfiguration
    @State private var selectedClickAction: RecordClickAction
    @State private var selectedRetentionPolicy: HistoryRetentionPolicy
    @State private var selectedWindowPosition: HistoryWindowPosition
    @State private var isRecordingShortcut = false
    @State private var inputError: String?
    @State private var statusMessage: String?
    @State private var keyMonitor: Any?

    public init(store: ClipboardStore, hotkeyManager: GlobalHotkeyManager) {
        self.store = store
        self.hotkeyManager = hotkeyManager
        _draftConfiguration = State(initialValue: hotkeyManager.configuration)
        _selectedClickAction = State(initialValue: store.clickAction)
        _selectedRetentionPolicy = State(initialValue: store.retentionPolicy)
        _selectedWindowPosition = State(initialValue: currentHistoryWindowPosition())
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                toggleHistoryWindowFromMenu()
            } label: {
                Label(L10n.tr("menu.open_history"), systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.18))
                    )
            }
            .buttonStyle(.plain)

            Divider()

            Menu {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        languageManager.setLanguage(language)
                    } label: {
                        if languageManager.selectedLanguage == language {
                            Text("✓ \(L10n.tr(language.titleKey))")
                        } else {
                            Text(L10n.tr(language.titleKey))
                        }
                    }
                }
            } label: {
                Label(L10n.tr("menu.language"), systemImage: "globe")
            }

            Divider()

            settingHeader(L10n.tr("menu.hotkey"), icon: "keyboard")

            Button {
                startRecordingShortcut()
            } label: {
                Text(isRecordingShortcut ? L10n.tr("menu.hotkey.recording") : hotkeyManager.displayString(for: draftConfiguration))
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(L10n.tr("menu.hotkey.record_hint"))
                .font(.caption2)
                .foregroundStyle(.secondary)

            settingHeader(L10n.tr("menu.copy_rule"), icon: "doc.on.clipboard")

            Picker(L10n.tr("menu.copy_rule"), selection: $selectedClickAction) {
                ForEach(RecordClickAction.allCases) { action in
                    Text(action.title).tag(action)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .onChange(of: selectedClickAction) { value in
                store.updateClickAction(value)
            }

            settingHeader(L10n.tr("menu.popup_position"), icon: "rectangle.3.group")

            Picker(L10n.tr("menu.popup_position"), selection: $selectedWindowPosition) {
                ForEach(HistoryWindowPosition.allCases) { position in
                    Text(L10n.tr(position.titleKey)).tag(position)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .onChange(of: selectedWindowPosition) { value in
                setHistoryWindowPosition(value)
                repositionVisibleHistoryWindow()
            }

            settingHeader(L10n.tr("menu.retention_policy"), icon: "clock.arrow.trianglehead.counterclockwise.rotate.90")

            Picker(L10n.tr("menu.retention_policy"), selection: $selectedRetentionPolicy) {
                ForEach(HistoryRetentionPolicy.allCases) { policy in
                    Text(policy.title).tag(policy)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .onChange(of: selectedRetentionPolicy) { value in
                store.updateRetentionPolicy(value)
            }

            if let inputError {
                Text(inputError)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if let statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            if let error = hotkeyManager.registrationError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    store.importHistoryFromTXT()
                } label: {
                    Label(L10n.tr("menu.import_txt_history"), systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    store.exportHistoryAsTXT()
                } label: {
                    Label(L10n.tr("menu.export_txt_history"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(store.items.isEmpty)
            }

            Button {
                store.clearAll()
            } label: {
                Label(L10n.tr("menu.clear_history"), systemImage: "trash")
            }
            .disabled(store.items.isEmpty)

            Divider()

            Button {
                stopRecordingShortcut()
                NSApp.terminate(nil)
            } label: {
                Label(L10n.tr("menu.quit"), systemImage: "power")
            }
        }
        .padding(8)
        .frame(minWidth: 300)
        .onAppear {
            syncFromManager()
        }
        .onDisappear {
            stopRecordingShortcut()
        }
    }

    @MainActor
    private func toggleHistoryWindowFromMenu() {
        guard let historyWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "historyWindow" }) else {
            openWindow(id: "history")
            activateHistoryWindow()
            return
        }

        if historyWindow.isVisible {
            let isFrontmost = NSApp.isActive && (historyWindow.isKeyWindow || historyWindow.isMainWindow)
            if isFrontmost {
                hideHistoryWindow()
            } else {
                NSApp.activate(ignoringOtherApps: true)
                historyWindow.makeKeyAndOrderFront(nil)
                historyWindow.orderFrontRegardless()
            }
            return
        }

        historyWindow.makeKeyAndOrderFront(nil)
        activateHistoryWindow()
    }

    private func syncFromManager() {
        draftConfiguration = hotkeyManager.configuration
        selectedClickAction = store.clickAction
        selectedRetentionPolicy = store.retentionPolicy
        selectedWindowPosition = currentHistoryWindowPosition()
        inputError = nil
        statusMessage = nil
    }

    private func startRecordingShortcut() {
        guard keyMonitor == nil else {
            isRecordingShortcut = true
            return
        }

        inputError = nil
        statusMessage = nil
        isRecordingShortcut = true
        hotkeyManager.setTriggerHandlingPaused(true)
        hotkeyManager.suspendRegistration()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                self.inputError = nil
                self.stopRecordingShortcut()
                return nil
            }

            let modifierFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !modifierFlags.isEmpty else {
                self.inputError = L10n.tr("menu.error.require_modifier")
                return nil
            }

            guard self.hotkeyManager.keyChoices.contains(where: { $0.keyCode == event.keyCode }) else {
                self.inputError = L10n.tr("menu.error.only_alnum")
                return nil
            }

            let capturedConfiguration = HotkeyConfiguration(
                keyCode: UInt32(event.keyCode),
                command: modifierFlags.contains(.command),
                option: modifierFlags.contains(.option),
                control: modifierFlags.contains(.control),
                shift: modifierFlags.contains(.shift)
            )

            let isSameAsCurrent = capturedConfiguration == self.hotkeyManager.configuration
            self.draftConfiguration = capturedConfiguration
            self.hotkeyManager.update(configuration: capturedConfiguration)
            self.inputError = nil
            self.statusMessage = isSameAsCurrent ? L10n.tr("menu.status.hotkey_reapplied") : L10n.tr("menu.status.hotkey_updated")
            self.stopRecordingShortcut()
            return nil
        }
    }

    private func stopRecordingShortcut() {
        isRecordingShortcut = false
        hotkeyManager.setTriggerHandlingPaused(false)
        hotkeyManager.resumeRegistration()
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func settingHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#if DEBUG
#Preview("Menu Bar Settings") {
    MenuBarHistoryView(
        store: .preview(
            items: PreviewFixtures.menuItems,
            clickAction: .copyAndAutoPaste
        ),
        hotkeyManager: .preview(configuration: PreviewFixtures.hotkeyConfiguration)
    )
    .padding()
    .frame(width: 320)
}
#endif
