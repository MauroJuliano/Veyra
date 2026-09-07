import Foundation

protocol ConversationRepository {
    func fetchConversations() -> [Conversation]
    func save(_ conversation: Conversation)
}

protocol MessageCacheRepository {
    func fetchMessages(conversationID: UUID, before: Date?, limit: Int) -> [Message]
    func saveMessages(_ messages: [Message], conversationID: UUID)
    func deleteMessage(id: UUID)
}

final class InMemoryMessageCacheRepository: MessageCacheRepository {
    private var storage: [UUID: [Message]] = [:]

    func fetchMessages(conversationID: UUID, before: Date?, limit: Int) -> [Message] {
        let messages = storage[conversationID, default: []]
            .filter { before == nil || $0.sentAt < before! }
            .sorted { $0.sentAt > $1.sentAt }
            .prefix(limit)
        return messages.sorted { $0.sentAt < $1.sentAt }
    }

    func saveMessages(_ messages: [Message], conversationID: UUID) {
        var indexed = Dictionary(uniqueKeysWithValues: storage[conversationID, default: []].map { ($0.id, $0) })
        messages.forEach { indexed[$0.id] = $0 }
        storage[conversationID] = indexed.values.sorted { $0.sentAt < $1.sentAt }.suffix(200)
    }

    func deleteMessage(id: UUID) {
        for conversationID in storage.keys {
            storage[conversationID]?.removeAll { $0.id == id }
        }
    }
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
