import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "veyra.selectedLanguage"

    case system
    case english
    case portugueseBrazil

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "System language", table: "Language")
        case .english: "English"
        case .portugueseBrazil: "Português (Brasil)"
        }
    }

    var subtitle: String {
        switch self {
        case .system: String(localized: "Follow your device language", table: "Language")
        case .english: "English"
        case .portugueseBrazil: "Português do Brasil"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .english: Locale(identifier: "en")
        case .portugueseBrazil: Locale(identifier: "pt-BR")
        }
    }

    var languageCode: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .portugueseBrazil: "pt-BR"
        }
    }

    func persistInSystemPreferences(defaults: UserDefaults = .standard) {
        if let languageCode {
            defaults.set([languageCode], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}
