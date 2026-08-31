import Foundation

struct Conversation: Identifiable, Hashable {
    let id: UUID
    let participantName: String
    let lastMessage: String
    let updatedAt: Date
    let unreadCount: Int
    let isOnline: Bool

    init(id: UUID = UUID(), participantName: String, lastMessage: String, updatedAt: Date, unreadCount: Int = 0, isOnline: Bool = false) {
        self.id = id
        self.participantName = participantName
        self.lastMessage = lastMessage
        self.updatedAt = updatedAt
        self.unreadCount = unreadCount
        self.isOnline = isOnline
    }
}
