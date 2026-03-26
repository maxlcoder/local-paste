import AppKit
import SwiftUI

struct MenuBarHistoryView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.openWindow) private var openWindow

    @State private var draftConfiguration: HotkeyConfiguration
    @State private var selectedClickAction: RecordClickAction
    @State private var selectedWindowPosition: HistoryWindowPosition
    @State private var isRecordingShortcut = false
    @State private var inputError: String?
    @State private var statusMessage: String?
    @State private var keyMonitor: Any?

    init(store: ClipboardStore, hotkeyManager: GlobalHotkeyManager) {
        self.store = store
        self.hotkeyManager = hotkeyManager
        _draftConfiguration = State(initialValue: hotkeyManager.configuration)
        _selectedClickAction = State(initialValue: store.clickAction)
        _selectedWindowPosition = State(initialValue: currentHistoryWindowPosition())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu(L10n.tr("menu.language")) {
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
            }

            Divider()

            Text(L10n.tr("menu.hotkey"))
                .font(.caption)
                .foregroundStyle(.secondary)

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

            Text(L10n.tr("menu.copy_rule"))
                .font(.caption)
                .foregroundStyle(.secondary)

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

            Text(L10n.tr("menu.popup_position"))
                .font(.caption)
                .foregroundStyle(.secondary)

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

            Button(L10n.tr("menu.open_history")) {
                toggleHistoryWindowFromMenu()
            }

            Divider()

            Button(L10n.tr("menu.import_txt_history")) {
                store.importHistoryFromTXT()
            }

            Button(L10n.tr("menu.export_txt_history")) {
                store.exportHistoryAsTXT()
            }
            .disabled(store.items.isEmpty)

            Button(L10n.tr("menu.clear_history")) {
                store.clearAll()
            }
            .disabled(store.items.isEmpty)

            Divider()

            Button(L10n.tr("menu.quit")) {
                stopRecordingShortcut()
                NSApp.terminate(nil)
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
                historyWindow.orderOut(nil)
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
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}
