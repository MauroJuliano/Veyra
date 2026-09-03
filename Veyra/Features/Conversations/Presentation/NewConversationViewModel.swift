import Foundation
import Observation

@Observable
final class NewConversationViewModel {
    private let repository: (any RemoteChatRepository)?
    private let recentStore: RecentPeopleStore
    var searchText = ""
    private(set) var results: [User] = []
    private(set) var recentUsers: [User]
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    init(repository: (any RemoteChatRepository)? = nil, recentStore: RecentPeopleStore = RecentPeopleStore()) {
        self.repository = repository
        self.recentStore = recentStore
        recentUsers = recentStore.load()
    }

    @MainActor
    func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, let repository else {
            results = []
            errorMessage = nil
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            try await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            results = try await repository.searchPeople(query: query)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }

    func addRecent(_ user: User) {
        recentUsers.removeAll { $0.id == user.id }
        recentUsers.insert(user, at: 0)
        recentUsers = Array(recentUsers.prefix(10))
        recentStore.save(recentUsers)
    }

    func removeRecent(_ user: User) {
        recentUsers.removeAll { $0.id == user.id }
        recentStore.save(recentUsers)
    }
}

final class RecentPeopleStore {
    private let defaults: UserDefaults
    private let key = "veyra.recentPeople"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> [User] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([User].self, from: data)) ?? []
    }

    func save(_ users: [User]) {
        guard let data = try? JSONEncoder().encode(users) else { return }
        defaults.set(data, forKey: key)
    }
}
