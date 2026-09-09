import Foundation
import SwiftData

final class SwiftDataConversationRepository: ConversationRepository, ContactRepository, MessageCacheRepository {
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
        let container = try ModelContainer(
            for: ConversationRecord.self,
            ContactRecord.self,
            LocalMessageRecord.self,
            LocalCallHistoryRecord.self,
            CallHistorySyncRecord.self,
            configurations: configuration
        )
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

    func deleteConversation(id: UUID) {
        let identifier = id
        let conversations = FetchDescriptor<ConversationRecord>(
            predicate: #Predicate { $0.id == identifier }
        )
        let messages = FetchDescriptor<LocalMessageRecord>(
            predicate: #Predicate { $0.conversationID == identifier }
        )

        (try? context.fetch(conversations))?.forEach(context.delete)
        (try? context.fetch(messages))?.forEach(context.delete)
        try? context.save()
    }

    func fetchContacts() -> [Contact] {
        let descriptor = FetchDescriptor<ContactRecord>(sortBy: [SortDescriptor(\.name)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.contact)
    }

    func saveContacts(_ contacts: [Contact]) {
        let incomingIDs = Set(contacts.map(\.id))
        let existing = (try? context.fetch(FetchDescriptor<ContactRecord>())) ?? []
        existing.filter { !incomingIDs.contains($0.id) }.forEach(context.delete)

        for contact in contacts {
            if let record = existing.first(where: { $0.id == contact.id }) {
                record.update(with: contact)
            } else {
                context.insert(ContactRecord(contact: contact))
            }
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

    func fetchCallHistory(participantID: UUID) -> [VoiceCallHistory] {
        let identifier = participantID
        let descriptor = FetchDescriptor<LocalCallHistoryRecord>(
            predicate: #Predicate { $0.participantID == identifier },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return ((try? context.fetch(descriptor)) ?? []).compactMap(\.call)
    }

    func replaceCallHistory(_ calls: [VoiceCallHistory], participantID: UUID) {
        let identifier = participantID
        let descriptor = FetchDescriptor<LocalCallHistoryRecord>(
            predicate: #Predicate { $0.participantID == identifier }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        let incomingIDs = Set(calls.map(\.id))
        existing.filter { !incomingIDs.contains($0.id) }.forEach(context.delete)

        for call in calls {
            if let record = existing.first(where: { $0.id == call.id }) {
                record.update(with: call, participantID: participantID)
            } else {
                context.insert(LocalCallHistoryRecord(call: call, participantID: participantID))
            }
        }

        let syncDescriptor = FetchDescriptor<CallHistorySyncRecord>(
            predicate: #Predicate { $0.participantID == identifier }
        )
        if let syncRecord = try? context.fetch(syncDescriptor).first {
            syncRecord.synchronizedAt = .now
        } else {
            context.insert(CallHistorySyncRecord(participantID: participantID))
        }
        try? context.save()
    }

    func hasCachedCallHistory(participantID: UUID) -> Bool {
        let identifier = participantID
        let descriptor = FetchDescriptor<CallHistorySyncRecord>(
            predicate: #Predicate { $0.participantID == identifier }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
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
