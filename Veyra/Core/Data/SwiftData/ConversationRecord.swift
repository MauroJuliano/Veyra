import Foundation
import SwiftData

@Model
final class ConversationRecord {
    @Attribute(.unique) var id: UUID
    var participantID: UUID?
    var participantName: String
    var lastMessage: String
    var updatedAt: Date
    var unreadCount: Int
    var isOnline: Bool
    var lastSeenAt: Date?
    var lastMessageIsMine: Bool = false
    var lastMessageIsRead: Bool = false
    var participantAvatarURLString: String?

    init(conversation: Conversation) {
        id = conversation.id
        participantID = conversation.participantID
        participantName = conversation.participantName
        lastMessage = conversation.lastMessage
        updatedAt = conversation.updatedAt
        unreadCount = conversation.unreadCount
        isOnline = conversation.isOnline
        lastSeenAt = conversation.lastSeenAt
        lastMessageIsMine = conversation.lastMessageIsMine
        lastMessageIsRead = conversation.lastMessageIsRead
        participantAvatarURLString = conversation.participantAvatarURL?.absoluteString
    }

    var conversation: Conversation {
        Conversation(
            id: id,
            participantID: participantID,
            participantName: participantName,
            lastMessage: lastMessage,
            updatedAt: updatedAt,
            unreadCount: unreadCount,
            isOnline: isOnline,
            lastSeenAt: lastSeenAt,
            lastMessageIsMine: lastMessageIsMine,
            lastMessageIsRead: lastMessageIsRead,
            participantAvatarURL: participantAvatarURLString.flatMap(URL.init(string:))
        )
    }

    func update(with conversation: Conversation) {
        participantID = conversation.participantID
        participantName = conversation.participantName
        lastMessage = conversation.lastMessage
        updatedAt = conversation.updatedAt
        unreadCount = conversation.unreadCount
        isOnline = conversation.isOnline
        lastSeenAt = conversation.lastSeenAt
        lastMessageIsMine = conversation.lastMessageIsMine
        lastMessageIsRead = conversation.lastMessageIsRead
        participantAvatarURLString = conversation.participantAvatarURL?.absoluteString
    }
}

@Model
final class LocalMessageRecord {
    @Attribute(.unique) var id: UUID
    var conversationID: UUID
    var text: String
    var sentAt: Date
    var directionRaw: String
    var receiptRaw: String
    var imageURLString: String?
    var isSticker: Bool
    var replyMessageID: UUID?
    var replyText: String?
    var replyIsOwnMessage: Bool?
    var reactionsData: Data

    init(message: Message, conversationID: UUID) {
        id = message.id
        self.conversationID = conversationID
        text = message.text
        sentAt = message.sentAt
        directionRaw = message.direction == .outgoing ? "outgoing" : "incoming"
        receiptRaw = message.receipt == .read ? "read" : "sent"
        imageURLString = message.imageURL?.absoluteString
        isSticker = message.isSticker
        replyMessageID = message.replyPreview?.messageID
        replyText = message.replyPreview?.text
        replyIsOwnMessage = message.replyPreview?.isOwnMessage
        reactionsData = (try? JSONEncoder().encode(message.reactions.map(CachedReaction.init))) ?? Data()
    }

    var message: Message {
        let reactions = ((try? JSONDecoder().decode([CachedReaction].self, from: reactionsData)) ?? []).map(\.reaction)
        let reply = replyMessageID.map {
            Message.ReplyPreview(messageID: $0, text: replyText ?? "Message unavailable", isOwnMessage: replyIsOwnMessage ?? false)
        }
        return Message(
            id: id,
            text: text,
            sentAt: sentAt,
            direction: directionRaw == "outgoing" ? .outgoing : .incoming,
            receipt: receiptRaw == "read" ? .read : .sent,
            imageURL: imageURLString.flatMap(URL.init(string:)),
            isSticker: isSticker,
            replyPreview: reply,
            reactions: reactions
        )
    }

    func update(with message: Message, conversationID: UUID) {
        self.conversationID = conversationID
        text = message.text
        sentAt = message.sentAt
        directionRaw = message.direction == .outgoing ? "outgoing" : "incoming"
        receiptRaw = message.receipt == .read ? "read" : "sent"
        imageURLString = message.imageURL?.absoluteString
        isSticker = message.isSticker
        replyMessageID = message.replyPreview?.messageID
        replyText = message.replyPreview?.text
        replyIsOwnMessage = message.replyPreview?.isOwnMessage
        reactionsData = (try? JSONEncoder().encode(message.reactions.map(CachedReaction.init))) ?? Data()
    }
}

private struct CachedReaction: Codable {
    let emoji: String
    let count: Int
    let isSelectedByCurrentUser: Bool

    init(_ reaction: Message.Reaction) {
        emoji = reaction.emoji
        count = reaction.count
        isSelectedByCurrentUser = reaction.isSelectedByCurrentUser
    }

    var reaction: Message.Reaction {
        Message.Reaction(emoji: emoji, count: count, isSelectedByCurrentUser: isSelectedByCurrentUser)
    }
}
