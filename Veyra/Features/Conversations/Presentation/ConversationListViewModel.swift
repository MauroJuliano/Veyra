import Foundation
import Observation

@Observable
final class ConversationListViewModel {
    private(set) var conversations: [Conversation]

    init(conversations: [Conversation] = ConversationPreviewData.conversations) {
        self.conversations = conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }
}
