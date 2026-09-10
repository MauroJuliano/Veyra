import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "veyra.selectedLanguage"

    case system
    case english
    case portugueseBrazil
    case german

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: AppLocalization.string("System language", table: "Language")
        case .english: AppLocalization.string("English", table: "Language")
        case .portugueseBrazil: AppLocalization.string("Portuguese", table: "Language")
        case .german: AppLocalization.string("German", table: "Language")
        }
    }

    var subtitle: String {
        switch self {
        case .system: AppLocalization.string("Follow your device language", table: "Language")
        case .english: "English"
        case .portugueseBrazil: "Português brasileiro"
        case .german: "Deutsch"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .english: Locale(identifier: "en")
        case .portugueseBrazil: Locale(identifier: "pt-BR")
        case .german: Locale(identifier: "de")
        }
    }

    var languageCode: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .portugueseBrazil: "pt-BR"
        case .german: "de"
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
