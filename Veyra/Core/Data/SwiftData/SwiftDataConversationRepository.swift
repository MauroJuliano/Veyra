import Foundation
import SwiftData

final class SwiftDataConversationRepository: ConversationRepository {
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
        let container = try ModelContainer(for: ConversationRecord.self, configurations: configuration)
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
}
