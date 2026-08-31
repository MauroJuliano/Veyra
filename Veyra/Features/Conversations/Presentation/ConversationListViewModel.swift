import Foundation
import Observation

@Observable
final class ConversationListViewModel {
    private let repository: any ConversationRepository
    private(set) var conversations: [Conversation]
    var searchText = ""

    init(repository: any ConversationRepository = InMemoryConversationRepository()) {
        self.repository = repository
        conversations = repository.fetchConversations()
    }

    convenience init(conversations: [Conversation]) {
        self.init(repository: InMemoryConversationRepository(conversations: conversations))
    }

    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var filteredConversations: [Conversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return conversations }
        return conversations.filter {
            $0.participantName.localizedStandardContains(query) || $0.lastMessage.localizedStandardContains(query)
        }
    }

    var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func add(_ conversation: Conversation) {
        repository.save(conversation)
        conversations = repository.fetchConversations()
    }
}
