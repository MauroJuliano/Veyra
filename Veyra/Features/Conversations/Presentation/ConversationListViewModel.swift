import Foundation
import Observation

@Observable
final class ConversationListViewModel {
    private(set) var conversations: [Conversation]
    var searchText = ""

    init(conversations: [Conversation] = ConversationPreviewData.conversations) {
        self.conversations = conversations.sorted { $0.updatedAt > $1.updatedAt }
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
        conversations.insert(conversation, at: 0)
    }
}
