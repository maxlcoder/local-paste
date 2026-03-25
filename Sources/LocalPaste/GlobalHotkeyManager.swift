import AppKit
import Carbon
import Foundation

struct HotkeyKeyChoice: Identifiable, Hashable {
    let id: UInt32
    let keyCode: UInt32
    let label: String

    init(keyCode: UInt32, label: String) {
        self.id = keyCode
        self.keyCode = keyCode
        self.label = label
    }
}

struct HotkeyConfiguration: Codable, Equatable {
    var keyCode: UInt32
    var command: Bool
    var option: Bool
    var control: Bool
    var shift: Bool

    static let `default` = HotkeyConfiguration(
        keyCode: 9, // V
        command: true,
        option: false,
        control: false,
        shift: true
    )

    var carbonModifiers: UInt32 {
        var modifiers: UInt32 = 0
        if command { modifiers |= UInt32(cmdKey) }
        if option { modifiers |= UInt32(optionKey) }
        if control { modifiers |= UInt32(controlKey) }
        if shift { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    var readableModifiers: String {
        var result = ""
        if command { result += "⌘" }
        if option { result += "⌥" }
        if control { result += "⌃" }
        if shift { result += "⇧" }
        return result
    }
}

@MainActor
final class GlobalHotkeyManager: ObservableObject {
    @Published private(set) var configuration: HotkeyConfiguration
    @Published private(set) var registrationError: String?

    var onTriggered: (() -> Void)?
    private var isTriggerHandlingPaused = false

    let keyChoices: [HotkeyKeyChoice] = [
        HotkeyKeyChoice(keyCode: 0, label: "A"),
        HotkeyKeyChoice(keyCode: 11, label: "B"),
        HotkeyKeyChoice(keyCode: 8, label: "C"),
        HotkeyKeyChoice(keyCode: 2, label: "D"),
        HotkeyKeyChoice(keyCode: 14, label: "E"),
        HotkeyKeyChoice(keyCode: 3, label: "F"),
        HotkeyKeyChoice(keyCode: 5, label: "G"),
        HotkeyKeyChoice(keyCode: 4, label: "H"),
        HotkeyKeyChoice(keyCode: 34, label: "I"),
        HotkeyKeyChoice(keyCode: 38, label: "J"),
        HotkeyKeyChoice(keyCode: 40, label: "K"),
        HotkeyKeyChoice(keyCode: 37, label: "L"),
        HotkeyKeyChoice(keyCode: 46, label: "M"),
        HotkeyKeyChoice(keyCode: 45, label: "N"),
        HotkeyKeyChoice(keyCode: 31, label: "O"),
        HotkeyKeyChoice(keyCode: 35, label: "P"),
        HotkeyKeyChoice(keyCode: 12, label: "Q"),
        HotkeyKeyChoice(keyCode: 15, label: "R"),
        HotkeyKeyChoice(keyCode: 1, label: "S"),
        HotkeyKeyChoice(keyCode: 17, label: "T"),
        HotkeyKeyChoice(keyCode: 32, label: "U"),
        HotkeyKeyChoice(keyCode: 9, label: "V"),
        HotkeyKeyChoice(keyCode: 13, label: "W"),
        HotkeyKeyChoice(keyCode: 7, label: "X"),
        HotkeyKeyChoice(keyCode: 16, label: "Y"),
        HotkeyKeyChoice(keyCode: 6, label: "Z"),
        HotkeyKeyChoice(keyCode: 18, label: "1"),
        HotkeyKeyChoice(keyCode: 19, label: "2"),
        HotkeyKeyChoice(keyCode: 20, label: "3"),
        HotkeyKeyChoice(keyCode: 21, label: "4"),
        HotkeyKeyChoice(keyCode: 23, label: "5"),
        HotkeyKeyChoice(keyCode: 22, label: "6"),
        HotkeyKeyChoice(keyCode: 26, label: "7"),
        HotkeyKeyChoice(keyCode: 28, label: "8"),
        HotkeyKeyChoice(keyCode: 25, label: "9"),
        HotkeyKeyChoice(keyCode: 29, label: "0")
    ]

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private let storageKey = "LocalPaste.GlobalHotkeyConfiguration"
    private let hotkeySignature: OSType = 0x4C505354 // LPST
    private let hotkeyID: UInt32 = 1

    init() {
        self.configuration = Self.loadConfiguration(storageKey: storageKey) ?? .default
        installEventHandlerIfNeeded()
        registerCurrentHotkey()
    }

    func update(configuration: HotkeyConfiguration) {
        self.configuration = configuration
        persist(configuration)
        registerCurrentHotkey()
    }

    func setTriggerHandlingPaused(_ paused: Bool) {
        isTriggerHandlingPaused = paused
    }

    func resetToDefault() {
        update(configuration: .default)
    }

    func displayString(for configuration: HotkeyConfiguration? = nil) -> String {
        let config = configuration ?? self.configuration
        let keyLabel = keyChoices.first(where: { $0.keyCode == config.keyCode })?.label ?? "?"
        return "\(config.readableModifiers)\(keyLabel)"
    }

    private func installEventHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkeyEvent(eventRef)
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }

    private func handleHotkeyEvent(_ eventRef: EventRef?) {
        guard let eventRef else { return }

        var eventHotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &eventHotKeyID
        )

        guard status == noErr else { return }
        guard eventHotKeyID.signature == hotkeySignature && eventHotKeyID.id == hotkeyID else { return }
        guard !isTriggerHandlingPaused else { return }

        onTriggered?()
    }

    private func registerCurrentHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        let eventHotKeyID = EventHotKeyID(signature: hotkeySignature, id: hotkeyID)

        let status = RegisterEventHotKey(
            configuration.keyCode,
            configuration.carbonModifiers,
            eventHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            registrationError = nil
        } else {
            registrationError = L10n.tr("hotkey.error.register_failed")
        }
    }

    private func persist(_ configuration: HotkeyConfiguration) {
        do {
            let data = try JSONEncoder().encode(configuration)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Ignore persistence failures to avoid blocking the UI.
        }
    }

    private static func loadConfiguration(storageKey: String) -> HotkeyConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(HotkeyConfiguration.self, from: data)
    }
}
