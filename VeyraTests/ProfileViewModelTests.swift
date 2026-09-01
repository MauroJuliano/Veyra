import Testing
@testable import Veyra

struct ProfileViewModelTests {
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
