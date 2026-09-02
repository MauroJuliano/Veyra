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

    @Test func persistsCompleteMessageOffline() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ConversationRecord.self, LocalMessageRecord.self, configurations: configuration)
        let repository = SwiftDataConversationRepository(container: container)
        let conversationID = UUID()
        let originalID = UUID()
        let message = Message(
            text: "Offline reply",
            direction: .outgoing,
            receipt: .read,
            replyPreview: .init(messageID: originalID, text: "Original", isOwnMessage: false),
            reactions: [.init(emoji: "❤️", count: 2, isSelectedByCurrentUser: true)]
        )

        repository.saveMessages([message], conversationID: conversationID)
        let restored = repository.fetchMessages(conversationID: conversationID, before: nil, limit: 50)

        #expect(restored == [message])
    }

    @Test func keepsOnlyMostRecentTwoHundredMessages() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ConversationRecord.self, LocalMessageRecord.self, configurations: configuration)
        let repository = SwiftDataConversationRepository(container: container)
        let conversationID = UUID()
        let messages = (0..<205).map {
            Message(text: "Message \($0)", sentAt: Date(timeIntervalSince1970: TimeInterval($0)), direction: .incoming)
        }

        repository.saveMessages(messages, conversationID: conversationID)
        let restored = repository.fetchMessages(conversationID: conversationID, before: nil, limit: 300)

        #expect(restored.count == 200)
        #expect(restored.first?.text == "Message 5")
        #expect(restored.last?.text == "Message 204")
    }
}
