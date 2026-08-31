import Foundation
import Testing
@testable import Veyra

struct RepositoryTests {
    @Test func conversationRepositoryPersistsAndSortsConversations() {
        let older = Conversation(participantName: "Older", lastMessage: "Hello", updatedAt: Date(timeIntervalSince1970: 10))
        let repository = InMemoryConversationRepository(conversations: [older])
        let newer = Conversation(participantName: "Newer", lastMessage: "Hi", updatedAt: Date(timeIntervalSince1970: 20))

        repository.save(newer)

        #expect(repository.fetchConversations().map(\.id) == [newer.id, older.id])
    }

    @Test func contactRepositorySortsContactsByName() {
        let repository = InMemoryContactRepository(contacts: [Contact(name: "Zoe"), Contact(name: "Ana")])

        #expect(repository.fetchContacts().map(\.name) == ["Ana", "Zoe"])
    }
}
