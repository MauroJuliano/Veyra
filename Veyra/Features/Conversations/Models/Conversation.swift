import Foundation

struct Conversation: Identifiable, Hashable {
    let id: UUID
    let participantID: UUID?
    let participantName: String
    let lastMessage: String
    let updatedAt: Date
    let unreadCount: Int
    let isOnline: Bool
    let lastSeenAt: Date?
    let lastMessageIsMine: Bool
    let lastMessageIsRead: Bool

    init(id: UUID = UUID(), participantID: UUID? = nil, participantName: String, lastMessage: String, updatedAt: Date, unreadCount: Int = 0, isOnline: Bool = false, lastSeenAt: Date? = nil, lastMessageIsMine: Bool = false, lastMessageIsRead: Bool = false) {
        self.id = id
        self.participantID = participantID
        self.participantName = participantName
        self.lastMessage = lastMessage
        self.updatedAt = updatedAt
        self.unreadCount = unreadCount
        self.isOnline = isOnline
        self.lastSeenAt = lastSeenAt
        self.lastMessageIsMine = lastMessageIsMine
        self.lastMessageIsRead = lastMessageIsRead
    }
}
