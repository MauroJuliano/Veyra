import Foundation
import Testing
@testable import Veyra

struct ConversationListViewModelTests {
    @Test func startsWithLocallyCachedConversationsWhenRemoteExists() {
        let conversation = Conversation(participantName: "Offline contact", lastMessage: "Cached", updatedAt: .now)
        let localRepository = InMemoryConversationRepository(conversations: [conversation])
        let viewModel = ConversationListViewModel(
            repository: localRepository,
            remoteRepository: OfflineRemoteChatRepository()
        )

        #expect(viewModel.conversations.map(\.id) == [conversation.id])
    }

    @Test func sortsConversationsByMostRecentFirst() {
        let oldest = Conversation(participantName: "Oldest", lastMessage: "First", updatedAt: Date(timeIntervalSince1970: 100))
        let newest = Conversation(participantName: "Newest", lastMessage: "Second", updatedAt: Date(timeIntervalSince1970: 200))

        let viewModel = ConversationListViewModel(conversations: [oldest, newest])

        #expect(viewModel.conversations.map(\.id) == [newest.id, oldest.id])
    }

    @Test func calculatesTotalUnreadMessages() {
        let conversations = [
            Conversation(participantName: "Ana", lastMessage: "Hello", updatedAt: .now, unreadCount: 2),
            Conversation(participantName: "Lucas", lastMessage: "Hi", updatedAt: .now, unreadCount: 3)
        ]

        let viewModel = ConversationListViewModel(conversations: conversations)

        #expect(viewModel.totalUnreadCount == 5)
    }

    @Test func filtersByParticipantNameIgnoringCase() {
        let viewModel = ConversationListViewModel(conversations: [
            Conversation(participantName: "Ana Lima", lastMessage: "Hello", updatedAt: .now),
            Conversation(participantName: "Lucas Rocha", lastMessage: "Welcome", updatedAt: .now)
        ])
        viewModel.searchText = "ana"
        #expect(viewModel.filteredConversations.map(\.participantName) == ["Ana Lima"])
    }

    @Test func filtersByLastMessage() {
        let viewModel = ConversationListViewModel(conversations: [
            Conversation(participantName: "Ana", lastMessage: "Review the prototype", updatedAt: .now),
            Conversation(participantName: "Lucas", lastMessage: "See you later", updatedAt: .now)
        ])
        viewModel.searchText = "prototype"
        #expect(viewModel.filteredConversations.map(\.participantName) == ["Ana"])
    }

    @Test @MainActor func deletesLocalConversation() async {
        let conversation = Conversation(participantName: "Ana", lastMessage: "Hello", updatedAt: .now)
        let viewModel = ConversationListViewModel(conversations: [conversation])

        await viewModel.delete(conversation)

        #expect(viewModel.conversations.isEmpty)
    }
}

struct OfflineRemoteChatRepository: RemoteChatRepository {
    func fetchConversations() async throws -> [Conversation] { throw URLError(.notConnectedToInternet) }
    func startConversation(withEmail email: String) async throws -> Conversation { throw URLError(.notConnectedToInternet) }
    func startConversation(with contact: Contact) async throws -> Conversation { throw URLError(.notConnectedToInternet) }
    func fetchMessages(conversationID: UUID, before: Date?, limit: Int) async throws -> [Message] { throw URLError(.notConnectedToInternet) }
    func sendMessage(_ text: String, conversationID: UUID, replyingTo messageID: UUID?, clientMessageID: UUID?) async throws -> Message { throw URLError(.notConnectedToInternet) }
    func sendImage(_ data: Data, conversationID: UUID) async throws -> Message { throw URLError(.notConnectedToInternet) }
    func messageEvents(conversationID: UUID, participantID: UUID?) async throws -> AsyncStream<MessageEvent> { throw URLError(.notConnectedToInternet) }
    func setTyping(_ isTyping: Bool, conversationID: UUID) async throws { throw URLError(.notConnectedToInternet) }
    func conversationEvents() async throws -> AsyncStream<ConversationEvent> { throw URLError(.notConnectedToInternet) }
    func markConversationRead(conversationID: UUID) async throws { throw URLError(.notConnectedToInternet) }
    func deleteMessage(id: UUID) async throws { throw URLError(.notConnectedToInternet) }
    func toggleReaction(_ emoji: String, messageID: UUID) async throws { throw URLError(.notConnectedToInternet) }
    func deleteConversation(id: UUID) async throws { throw URLError(.notConnectedToInternet) }
    func fetchContacts() async throws -> [Contact] { throw URLError(.notConnectedToInternet) }
    func searchPeople(query: String) async throws -> [User] { throw URLError(.notConnectedToInternet) }
    func fetchMyProfile() async throws -> UserProfile { throw URLError(.notConnectedToInternet) }
    func updateMyAvatar(_ data: Data) async throws -> UserProfile { throw URLError(.notConnectedToInternet) }
    func maintainPresence() async {}
    func registerPushToken(_ token: String) async throws { throw URLError(.notConnectedToInternet) }
    func unregisterPushToken(_ token: String) async throws { throw URLError(.notConnectedToInternet) }
}
