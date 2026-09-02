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
        removeLegacyPreviewConversations()
    }

    convenience init(isStoredInMemoryOnly: Bool = false, seed: [Conversation] = []) throws {
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

    private func removeLegacyPreviewConversations() {
        let previewSignatures: Set<String> = [
            "Ana Lima|Vamos revisar o protótipo amanhã?",
            "Lucas Rocha|A nova navegação ficou muito boa.",
            "Marina Costa|Te envio as referências mais tarde.",
            "Rafael Alves|Obrigado pela ajuda!"
        ]
        let descriptor = FetchDescriptor<ConversationRecord>()
        guard let records = try? context.fetch(descriptor) else { return }
        let legacyRecords = records.filter {
            previewSignatures.contains("\($0.participantName)|\($0.lastMessage)")
        }
        guard !legacyRecords.isEmpty else { return }
        legacyRecords.forEach(context.delete)
        try? context.save()
    }
}
