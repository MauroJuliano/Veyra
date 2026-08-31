import Foundation
import Testing
@testable import Veyra

struct ConversationListViewModelTests {
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
}
