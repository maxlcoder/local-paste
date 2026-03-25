import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case en

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system:
            return "menu.language.system"
        case .zhHans:
            return "menu.language.zh"
        case .en:
            return "menu.language.en"
        }
    }

    var localizationCode: String? {
        switch self {
        case .system:
            return nil
        case .zhHans:
            return "zh-Hans"
        case .en:
            return "en"
        }
    }
}

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published private(set) var selectedLanguage: AppLanguage

    static let storageKey = "LocalPaste.AppLanguage"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let language = AppLanguage(rawValue: raw) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .system
        }
    }

    func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
    }
}
