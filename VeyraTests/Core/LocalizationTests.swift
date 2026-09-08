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
}
