import Foundation
import Testing
@testable import Veyra

struct ProfileViewModelTests {
    @Test func userDefaultsStorePersistsNameAndAvatar() throws {
        let suiteName = "ProfileViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsProfileStore(defaults: defaults)
        let avatarURL = try #require(URL(string: "https://example.com/profile.jpg"))
        let profile = UserProfile(displayName: "Saved name", username: "savedname", avatarURL: avatarURL)

        store.save(profile)

        #expect(store.load() == profile)
    }

    @Test @MainActor func savesNormalizedProfile() async {
        let store = InMemoryProfileStore()
        let viewModel = ProfileViewModel(store: store)
        viewModel.displayName = "  Mauro Juliano  "
        viewModel.username = "@MauroDev"
        viewModel.email = "MAURO@example.com"
        viewModel.bio = "  iOS developer  "

        #expect(await viewModel.save())
        #expect(store.load() == UserProfile(displayName: "Mauro Juliano", username: "maurodev", bio: "iOS developer", email: "mauro@example.com"))
    }

    @Test @MainActor func rejectsUsernameWithSpaces() async {
        let viewModel = ProfileViewModel(store: InMemoryProfileStore())
        viewModel.displayName = "Mauro Juliano"
        viewModel.username = "mauro dev"

        #expect(!(await viewModel.save()))
        #expect(viewModel.validationMessage != nil)
    }

    @Test @MainActor func rejectsInvalidEmail() async {
        let viewModel = ProfileViewModel(store: InMemoryProfileStore())
        viewModel.email = "not-an-email"

        #expect(!(await viewModel.save()))
        #expect(viewModel.validationMessage == "Enter a valid email address.")
    }

    @Test @MainActor func rejectsBioLongerThanOneHundredTwentyCharacters() async {
        let viewModel = ProfileViewModel(store: InMemoryProfileStore())
        viewModel.email = "member@example.com"
        viewModel.bio = String(repeating: "a", count: 121)

        #expect(!(await viewModel.save()))
        #expect(viewModel.validationMessage == "Bio must contain at most 120 characters.")
    }
}
