import Foundation
import Testing
@testable import Veyra

struct LocalizationTests {
    @Test func includesBrazilianPortugueseTranslations() throws {
        let path = try #require(Bundle.main.path(forResource: "pt-BR", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))

        #expect(bundle.localizedString(forKey: "Chats", value: nil, table: nil) == "Conversas")
        #expect(bundle.localizedString(forKey: "Create account", value: nil, table: nil) == "Criar conta")
        #expect(bundle.localizedString(forKey: "This username is already in use.", value: nil, table: nil) == "Este username já está em uso.")
    }

    @Test func includesGermanTranslations() throws {
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))

        #expect(bundle.localizedString(forKey: "Chats", value: nil, table: nil) == "Chats")
        #expect(bundle.localizedString(forKey: "Create account", value: nil, table: nil) == "Benutzerkonto erstellen")
        #expect(bundle.localizedString(forKey: "Last seen at %@", value: nil, table: "Language") == "Zuletzt online um %@")
    }

    @Test func productionCatalogsHaveCompleteTranslationCoverage() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        try assertCoverage(
            at: repositoryRoot.appending(path: "Veyra/Configuration/Localizable.xcstrings"),
            locales: ["pt-BR", "de"],
            // The extractor mirrors these custom-resolver calls into the default
            // catalog; their authoritative translations live in Language.xcstrings.
            ignoredKeys: [
                "",
                "English",
                "Follow your device language",
                "German",
                "Portuguese",
                "Some content may update after you reopen Veyra.",
                "System language"
            ]
        )
        try assertCoverage(
            at: repositoryRoot.appending(path: "Veyra/Features/Profile/Resources/Language.xcstrings"),
            locales: ["pt-BR", "de"]
        )
        try assertCoverage(
            at: repositoryRoot.appending(path: "Veyra/Configuration/Deletion.xcstrings"),
            locales: ["pt-BR", "de"]
        )
    }

    private func assertCoverage(at url: URL, locales: [String], ignoredKeys: Set<String> = []) throws {
        let data = try Data(contentsOf: url)
        let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])

        for locale in locales {
            let missing = strings.compactMap { key, rawValue -> String? in
                if key.isEmpty || ignoredKeys.contains(key) { return nil }

                guard let entry = rawValue as? [String: Any],
                      let localizations = entry["localizations"] as? [String: Any],
                      let localization = localizations[locale] as? [String: Any],
                      let stringUnit = localization["stringUnit"] as? [String: Any],
                      let value = stringUnit["value"] as? String,
                      !value.isEmpty else { return key }
                return nil
            }

            #expect(missing.isEmpty, "Missing \(locale) translations: \(missing.sorted())")
        }
    }
}
