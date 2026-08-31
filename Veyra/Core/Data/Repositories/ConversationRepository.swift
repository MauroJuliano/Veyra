import Foundation

protocol ConversationRepository {
    func fetchConversations() -> [Conversation]
    func save(_ conversation: Conversation)
}

final class InMemoryConversationRepository: ConversationRepository {
    private var storage: [Conversation]

    init(conversations: [Conversation] = ConversationPreviewData.conversations) {
        storage = conversations
    }

    func fetchConversations() -> [Conversation] {
        storage.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ conversation: Conversation) {
        storage.removeAll { $0.id == conversation.id }
        storage.append(conversation)
    }
}
