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
final class ContactRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var conversationID: UUID?
    var bio: String?
    var avatarURLString: String?

    init(contact: Contact) {
        id = contact.id
        name = contact.name
        conversationID = contact.conversationID
        bio = contact.bio
        avatarURLString = contact.avatarURL?.absoluteString
    }

    var contact: Contact {
        Contact(
            id: id,
            name: name,
            isOnline: false,
            conversationID: conversationID,
            bio: bio,
            avatarURL: avatarURLString.flatMap(URL.init(string:))
        )
    }

    func update(with contact: Contact) {
        name = contact.name
        conversationID = contact.conversationID
        bio = contact.bio
        avatarURLString = contact.avatarURL?.absoluteString
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
    var audioURLString: String?
    var audioDuration: Double?
    var isSticker: Bool
    var replyMessageID: UUID?
    var replyText: String?
    var replyIsOwnMessage: Bool?
    var reactionsData: Data
    var deliveryStateRaw: String = "sent"

    init(message: Message, conversationID: UUID) {
        id = message.id
        self.conversationID = conversationID
        text = message.text
        sentAt = message.sentAt
        directionRaw = message.direction == .outgoing ? "outgoing" : "incoming"
        receiptRaw = message.receipt == .read ? "read" : "sent"
        imageURLString = message.imageURL?.absoluteString
        audioURLString = message.audioURL?.absoluteString
        audioDuration = message.audioDuration
        isSticker = message.isSticker
        replyMessageID = message.replyPreview?.messageID
        replyText = message.replyPreview?.text
        replyIsOwnMessage = message.replyPreview?.isOwnMessage
        reactionsData = (try? JSONEncoder().encode(message.reactions.map(CachedReaction.init))) ?? Data()
        deliveryStateRaw = message.deliveryState.rawValue
    }

    var message: Message {
        let reactions = ((try? JSONDecoder().decode([CachedReaction].self, from: reactionsData)) ?? []).map(\.reaction)
        let storedDeliveryState = Message.DeliveryState(rawValue: deliveryStateRaw) ?? .sent
        let restoredDeliveryState: Message.DeliveryState = storedDeliveryState == .sending ? .failed : storedDeliveryState
        let reply = replyMessageID.map {
            Message.ReplyPreview(messageID: $0, text: replyText ?? String(localized: "Message unavailable"), isOwnMessage: replyIsOwnMessage ?? false)
        }
        return Message(
            id: id,
            text: text,
            sentAt: sentAt,
            direction: directionRaw == "outgoing" ? .outgoing : .incoming,
            receipt: receiptRaw == "read" ? .read : .sent,
            imageURL: imageURLString.flatMap(URL.init(string:)),
            audioURL: audioURLString.flatMap(URL.init(string:)),
            audioDuration: audioDuration,
            isSticker: isSticker,
            replyPreview: reply,
            reactions: reactions,
            deliveryState: restoredDeliveryState
        )
    }

    func update(with message: Message, conversationID: UUID) {
        self.conversationID = conversationID
        text = message.text
        sentAt = message.sentAt
        directionRaw = message.direction == .outgoing ? "outgoing" : "incoming"
        receiptRaw = message.receipt == .read ? "read" : "sent"
        imageURLString = message.imageURL?.absoluteString
        audioURLString = message.audioURL?.absoluteString
        audioDuration = message.audioDuration
        isSticker = message.isSticker
        replyMessageID = message.replyPreview?.messageID
        replyText = message.replyPreview?.text
        replyIsOwnMessage = message.replyPreview?.isOwnMessage
        reactionsData = (try? JSONEncoder().encode(message.reactions.map(CachedReaction.init))) ?? Data()
        deliveryStateRaw = message.deliveryState.rawValue
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
