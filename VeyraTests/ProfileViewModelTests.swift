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

    @Test func savesNormalizedProfile() {
        let store = InMemoryProfileStore()
        let viewModel = ProfileViewModel(store: store)
        viewModel.displayName = "  Mauro Juliano  "
        viewModel.username = "@MauroDev"

        #expect(viewModel.save())
        #expect(store.load() == UserProfile(displayName: "Mauro Juliano", username: "maurodev"))
    }

    @Test func rejectsUsernameWithSpaces() {
        let viewModel = ProfileViewModel(store: InMemoryProfileStore())
        viewModel.displayName = "Mauro Juliano"
        viewModel.username = "mauro dev"

        #expect(!viewModel.save())
        #expect(viewModel.validationMessage != nil)
    }
}
