import Foundation
import SwiftData
import Testing
@testable import Veyra

struct SwiftDataConversationRepositoryTests {
    @Test func savesConversationAcrossRepositoryInstances() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ConversationRecord.self, configurations: configuration)
        let writer = SwiftDataConversationRepository(container: container)
        let conversation = Conversation(participantName: "Persisted", lastMessage: "Hello", updatedAt: .now)

        writer.save(conversation)
        let reader = SwiftDataConversationRepository(container: container)

        #expect(reader.fetchConversations().map(\.id) == [conversation.id])
    }

    @Test func updatesExistingConversationWithoutDuplicatingIt() throws {
        let repository = try SwiftDataConversationRepository(isStoredInMemoryOnly: true, seed: [])
        let id = UUID()
        repository.save(Conversation(id: id, participantName: "Ana", lastMessage: "First", updatedAt: .now))
        repository.save(Conversation(id: id, participantName: "Ana", lastMessage: "Updated", updatedAt: .now))

        let conversations = repository.fetchConversations()
        #expect(conversations.count == 1)
        #expect(conversations[0].lastMessage == "Updated")
    }
}
