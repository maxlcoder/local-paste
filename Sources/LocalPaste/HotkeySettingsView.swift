import AppKit
import SwiftUI

struct HotkeySettingsView: View {
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
    @ObservedObject var store: ClipboardStore
    @Environment(\.dismiss) private var dismiss

    @State private var draftConfiguration: HotkeyConfiguration
    @State private var selectedClickAction: RecordClickAction
    @State private var inputError: String?
    @State private var isRecordingShortcut = false
    @State private var keyMonitor: Any?

    init(hotkeyManager: GlobalHotkeyManager, store: ClipboardStore) {
        self.hotkeyManager = hotkeyManager
        self.store = store
        _draftConfiguration = State(initialValue: hotkeyManager.configuration)
        _selectedClickAction = State(initialValue: store.clickAction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("快捷键设置")
                .font(.title3)
                .fontWeight(.semibold)

            Text("点击“开始录制”后，直接按下你的快捷键组合。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("快捷键")
                    .fontWeight(.medium)

                HStack(spacing: 10) {
                    Text(isRecordingShortcut ? "请按下组合键..." : hotkeyManager.displayString(for: draftConfiguration))
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minWidth: 180, alignment: .leading)
                        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button(isRecordingShortcut ? "停止录制" : "开始录制") {
                        if isRecordingShortcut {
                            stopRecordingShortcut()
                        } else {
                            startRecordingShortcut()
                        }
                    }
                }

                Text("必须包含至少一个修饰键（⌘ / ⌥ / ⌃ / ⇧）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("点击记录操作")
                    .fontWeight(.medium)

                Picker("点击记录操作", selection: $selectedClickAction) {
                    ForEach(RecordClickAction.allCases) { action in
                        Text(action.title).tag(action)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 320)
            }

            Text("当前组合: \(hotkeyManager.displayString(for: draftConfiguration))")
                .font(.headline)

            if let inputError {
                Text(inputError)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            if let error = hotkeyManager.registrationError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            HStack {
                Button("恢复默认") {
                    stopRecordingShortcut()
                    hotkeyManager.resetToDefault()
                    store.updateClickAction(.copyOnly)
                    syncFromManager()
                }

                Spacer()

                Button("取消") {
                    stopRecordingShortcut()
                    dismiss()
                }

                Button("保存") {
                    stopRecordingShortcut()
                    hotkeyManager.update(configuration: draftConfiguration)
                    store.updateClickAction(selectedClickAction)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 440, height: 380, alignment: .topLeading)
        .onDisappear {
            stopRecordingShortcut()
        }
    }

    private func syncFromManager() {
        draftConfiguration = hotkeyManager.configuration
        selectedClickAction = store.clickAction
        inputError = nil
    }

    private func startRecordingShortcut() {
        guard keyMonitor == nil else {
            isRecordingShortcut = true
            return
        }

        inputError = nil
        isRecordingShortcut = true
        hotkeyManager.setTriggerHandlingPaused(true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifierFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !modifierFlags.isEmpty else {
                self.inputError = "请至少包含一个修饰键"
                return nil
            }

            guard self.hotkeyManager.keyChoices.contains(where: { $0.keyCode == event.keyCode }) else {
                self.inputError = "仅支持字母和数字键"
                return nil
            }

            self.draftConfiguration = HotkeyConfiguration(
                keyCode: UInt32(event.keyCode),
                command: modifierFlags.contains(.command),
                option: modifierFlags.contains(.option),
                control: modifierFlags.contains(.control),
                shift: modifierFlags.contains(.shift)
            )
            self.inputError = nil
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

#if DEBUG
#Preview("Hotkey Settings") {
    HotkeySettingsView(
        hotkeyManager: .preview(configuration: PreviewFixtures.hotkeyConfiguration),
        store: .preview(items: PreviewFixtures.menuItems, clickAction: .copyAndAutoPaste)
    )
    .frame(width: 460, height: 410)
}
#endif
