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

    @Test func persistsConversationParticipantAndAvatarMetadata() throws {
        let repository = try SwiftDataConversationRepository(isStoredInMemoryOnly: true)
        let participantID = UUID()
        let avatarURL = try #require(URL(string: "https://example.com/avatar.jpg"))
        let lastSeenAt = Date(timeIntervalSince1970: 1_000)
        let conversation = Conversation(
            participantID: participantID,
            participantName: "Real contact",
            lastMessage: "Hello",
            updatedAt: .now,
            lastSeenAt: lastSeenAt,
            participantAvatarURL: avatarURL
        )

        repository.save(conversation)
        let restored = try #require(repository.fetchConversations().first)

        #expect(restored.participantID == participantID)
        #expect(restored.lastSeenAt == lastSeenAt)
        #expect(restored.participantAvatarURL == avatarURL)
    }

    @Test func removesLegacyPreviewConversations() throws {
        let preview = Conversation(
            participantName: "Ana Lima",
            lastMessage: "Vamos revisar o protótipo amanhã?",
            updatedAt: .now
        )
        let real = Conversation(participantName: "Ana Lima", lastMessage: "A real message", updatedAt: .now)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ConversationRecord.self, ContactRecord.self, LocalMessageRecord.self, configurations: configuration)
        let repository = SwiftDataConversationRepository(container: container, seed: [preview, real])

        #expect(repository.fetchConversations().map(\.id) == [real.id])
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

    @Test func persistsFailedDeliveryStateForRetry() throws {
        let repository = try SwiftDataConversationRepository(isStoredInMemoryOnly: true)
        let conversationID = UUID()
        let message = Message(text: "Queued", direction: .outgoing, deliveryState: .failed)

        repository.saveMessages([message], conversationID: conversationID)
        let restored = try #require(repository.fetchMessages(conversationID: conversationID, before: nil, limit: 50).first)

        #expect(restored.id == message.id)
        #expect(restored.deliveryState == .failed)
    }

    @Test func restoresInterruptedSendAsFailed() throws {
        let repository = try SwiftDataConversationRepository(isStoredInMemoryOnly: true)
        let conversationID = UUID()
        repository.saveMessages(
            [Message(text: "Interrupted", direction: .outgoing, deliveryState: .sending)],
            conversationID: conversationID
        )

        let restored = try #require(repository.fetchMessages(conversationID: conversationID, before: nil, limit: 50).first)

        #expect(restored.deliveryState == .failed)
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

    @Test func persistsContactNameAndAvatarOffline() throws {
        let repository = try SwiftDataConversationRepository(isStoredInMemoryOnly: true)
        let avatarURL = try #require(URL(string: "https://example.com/contact.jpg"))
        let contact = Contact(name: "Saved contact", conversationID: UUID(), bio: "Saved bio", avatarURL: avatarURL)

        repository.saveContacts([contact])
        let restored = try #require(repository.fetchContacts().first)

        #expect(restored.id == contact.id)
        #expect(restored.name == contact.name)
        #expect(restored.conversationID == contact.conversationID)
        #expect(restored.bio == contact.bio)
        #expect(restored.avatarURL == avatarURL)
        #expect(restored.isOnline == false)
    }
}
