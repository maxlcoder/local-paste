import Foundation

enum L10n {
    private static let languageStorageKey = "LocalPaste.AppLanguage"

    static func tr(_ key: String) -> String {
        let base = Bundle.module
        let code = selectedLanguageCode()

        if let path = base.path(forResource: code, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: languageBundle, value: key, comment: "")
        }

        return NSLocalizedString(key, tableName: nil, bundle: base, value: key, comment: "")
    }

    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: Locale.current, arguments: arguments)
    }

    private static func selectedLanguageCode() -> String {
        let selected = UserDefaults.standard.string(forKey: languageStorageKey)
            .flatMap(AppLanguage.init(rawValue:))
            ?? .system

        if let fixed = selected.localizationCode {
            return fixed
        }

        for preferred in Locale.preferredLanguages {
            let lower = preferred.lowercased()
            if lower.hasPrefix("zh") { return "zh-Hans" }
            if lower.hasPrefix("en") { return "en" }
        }
        return "zh-Hans"
    }
}
