import Foundation
import SwiftData

@Model
final class ConversationRecord {
    @Attribute(.unique) var id: UUID
    var participantName: String
    var lastMessage: String
    var updatedAt: Date
    var unreadCount: Int
    var isOnline: Bool
    var lastMessageIsMine: Bool = false
    var lastMessageIsRead: Bool = false

    init(conversation: Conversation) {
        id = conversation.id
        participantName = conversation.participantName
        lastMessage = conversation.lastMessage
        updatedAt = conversation.updatedAt
        unreadCount = conversation.unreadCount
        isOnline = conversation.isOnline
        lastMessageIsMine = conversation.lastMessageIsMine
        lastMessageIsRead = conversation.lastMessageIsRead
    }

    var conversation: Conversation {
        Conversation(
            id: id,
            participantName: participantName,
            lastMessage: lastMessage,
            updatedAt: updatedAt,
            unreadCount: unreadCount,
            isOnline: isOnline,
            lastMessageIsMine: lastMessageIsMine,
            lastMessageIsRead: lastMessageIsRead
        )
    }

    func update(with conversation: Conversation) {
        participantName = conversation.participantName
        lastMessage = conversation.lastMessage
        updatedAt = conversation.updatedAt
        unreadCount = conversation.unreadCount
        isOnline = conversation.isOnline
        lastMessageIsMine = conversation.lastMessageIsMine
        lastMessageIsRead = conversation.lastMessageIsRead
    }
}
