import Foundation
import SwiftData

final class SwiftDataConversationRepository: ConversationRepository, MessageCacheRepository {
    private let container: ModelContainer
    private let context: ModelContext

    init(container: ModelContainer, seed: [Conversation] = []) {
        self.container = container
        context = ModelContext(container)

        if fetchConversations().isEmpty {
            seed.forEach { context.insert(ConversationRecord(conversation: $0)) }
            try? context.save()
        }
    }

    convenience init(isStoredInMemoryOnly: Bool = false, seed: [Conversation] = ConversationPreviewData.conversations) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
        let container = try ModelContainer(for: ConversationRecord.self, LocalMessageRecord.self, configurations: configuration)
        self.init(container: container, seed: seed)
    }

    func fetchConversations() -> [Conversation] {
        let descriptor = FetchDescriptor<ConversationRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.map(\.conversation) ?? []
    }

    func save(_ conversation: Conversation) {
        let identifier = conversation.id
        let descriptor = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.id == identifier }
        )

        if let record = try? context.fetch(descriptor).first {
            record.update(with: conversation)
        } else {
            context.insert(ConversationRecord(conversation: conversation))
        }
        try? context.save()
    }

    func fetchMessages(conversationID: UUID, before: Date?, limit: Int) -> [Message] {
        let identifier = conversationID
        let boundary = before ?? .distantFuture
        var descriptor = FetchDescriptor<LocalMessageRecord>(
            predicate: #Predicate { $0.conversationID == identifier && $0.sentAt < boundary },
            sortBy: [SortDescriptor(\.sentAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).map(\.message).sorted { $0.sentAt < $1.sentAt }
    }

    func saveMessages(_ messages: [Message], conversationID: UUID) {
        for message in messages {
            let identifier = message.id
            let descriptor = FetchDescriptor<LocalMessageRecord>(predicate: #Predicate { $0.id == identifier })
            if let record = try? context.fetch(descriptor).first {
                record.update(with: message, conversationID: conversationID)
            } else {
                context.insert(LocalMessageRecord(message: message, conversationID: conversationID))
            }
        }
        trimMessages(conversationID: conversationID)
        try? context.save()
    }

    func deleteMessage(id: UUID) {
        let identifier = id
        let descriptor = FetchDescriptor<LocalMessageRecord>(predicate: #Predicate { $0.id == identifier })
        if let record = try? context.fetch(descriptor).first { context.delete(record) }
        try? context.save()
    }

    private func trimMessages(conversationID: UUID) {
        let identifier = conversationID
        let descriptor = FetchDescriptor<LocalMessageRecord>(
            predicate: #Predicate { $0.conversationID == identifier },
            sortBy: [SortDescriptor(\.sentAt, order: .reverse)]
        )
        guard let records = try? context.fetch(descriptor), records.count > 200 else { return }
        records.dropFirst(200).forEach(context.delete)
    }
}
