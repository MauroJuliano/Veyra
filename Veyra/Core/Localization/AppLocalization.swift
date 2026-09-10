import Foundation

enum AppLocalization {
    static var locale: Locale {
        let rawValue = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        return (rawValue.flatMap(AppLanguage.init(rawValue:)) ?? .system).locale
    }

    static func string(
        _ keyAndValue: String.LocalizationValue,
        table: String? = nil,
        locale: Locale? = nil,
        comment: StaticString? = nil
    ) -> String {
        String(
            localized: keyAndValue,
            table: table,
            locale: locale ?? self.locale,
            comment: comment
        )
    }
}
