import Foundation

protocol ConversationRepository {
    func fetchConversations() -> [Conversation]
    func save(_ conversation: Conversation)
}

protocol MessageCacheRepository {
    func fetchMessages(conversationID: UUID, before: Date?, limit: Int) -> [Message]
    func saveMessages(_ messages: [Message], conversationID: UUID)
    func deleteMessage(id: UUID)
    func fetchCallHistory(participantID: UUID) -> [VoiceCallHistory]
    func replaceCallHistory(_ calls: [VoiceCallHistory], participantID: UUID)
    func hasCachedCallHistory(participantID: UUID) -> Bool
}

final class InMemoryMessageCacheRepository: MessageCacheRepository {
    private var storage: [UUID: [Message]] = [:]
    private var callStorage: [UUID: [VoiceCallHistory]] = [:]
    private var synchronizedCallParticipants: Set<UUID> = []

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

    func fetchCallHistory(participantID: UUID) -> [VoiceCallHistory] {
        callStorage[participantID, default: []].sorted { $0.startedAt < $1.startedAt }
    }

    func replaceCallHistory(_ calls: [VoiceCallHistory], participantID: UUID) {
        callStorage[participantID] = calls
        synchronizedCallParticipants.insert(participantID)
    }

    func hasCachedCallHistory(participantID: UUID) -> Bool {
        synchronizedCallParticipants.contains(participantID)
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
