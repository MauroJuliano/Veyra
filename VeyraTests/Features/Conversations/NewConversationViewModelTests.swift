import Foundation
import Testing
@testable import Veyra

struct NewConversationViewModelTests {
    @Test func savesRecentPeopleMostRecentFirstWithoutDuplicates() throws {
        let suiteName = "RecentPeopleStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = RecentPeopleStore(defaults: defaults)
        let martha = User(participantName: "Martha Nielsen", userName: "@martha", participantAvatarURL: nil)
        let ulrich = User(participantName: "Ulrich Nielsen", userName: "@ulrich", participantAvatarURL: nil)
        let viewModel = NewConversationViewModel(recentStore: store)

        viewModel.addRecent(martha)
        viewModel.addRecent(ulrich)
        viewModel.addRecent(martha)

        #expect(viewModel.recentUsers.map(\.id) == [martha.id, ulrich.id])
        #expect(store.load().map(\.id) == [martha.id, ulrich.id])
    }

    @Test func removesRecentPersonPersistently() throws {
        let suiteName = "RecentPeopleStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = RecentPeopleStore(defaults: defaults)
        let martha = User(participantName: "Martha Nielsen", userName: "@martha", participantAvatarURL: nil)
        let viewModel = NewConversationViewModel(recentStore: store)
        viewModel.addRecent(martha)

        viewModel.removeRecent(martha)

        #expect(viewModel.recentUsers.isEmpty)
        #expect(store.load().isEmpty)
    }

    @Test @MainActor func shortQueryDoesNotCallRemoteSearch() async {
        let viewModel = NewConversationViewModel(repository: OfflineRemoteChatRepository())
        viewModel.searchText = "M"

        await viewModel.search()

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }
}
