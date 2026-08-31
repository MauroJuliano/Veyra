import Testing
@testable import Veyra

struct AvatarInitialsTests {
    @Test(arguments: [
        ("Mauro Figueiredo", "MF"),
        ("Veyra", "V"),
        ("  Ada   Lovelace  ", "AL"),
        ("", "")
    ])
    func createsInitials(name: String, expected: String) {
        #expect(AvatarInitials.make(from: name) == expected)
    }
}
