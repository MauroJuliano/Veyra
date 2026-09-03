import Foundation

struct Message: Identifiable, Hashable {
    struct ReplyPreview: Hashable {
        let messageID: UUID
        let text: String
        let isOwnMessage: Bool
    }

    struct Reaction: Hashable, Identifiable {
        let emoji: String
        let count: Int
        let isSelectedByCurrentUser: Bool
        var id: String { emoji }
    }
    enum Direction: Hashable {
        case incoming
        case outgoing
    }

    enum Receipt: Hashable {
        case sent
        case read
    }

    enum DeliveryState: String, Hashable {
        case sending
        case sent
        case failed
    }

    let id: UUID
    let text: String
    let sentAt: Date
    let direction: Direction
    let receipt: Receipt
    let imageURL: URL?
    let isSticker: Bool
    let replyPreview: ReplyPreview?
    var reactions: [Reaction]
    var deliveryState: DeliveryState

    init(id: UUID = UUID(), text: String, sentAt: Date = .now, direction: Direction, receipt: Receipt = .sent, imageURL: URL? = nil, isSticker: Bool = false, replyPreview: ReplyPreview? = nil, reactions: [Reaction] = [], deliveryState: DeliveryState = .sent) {
        self.id = id
        self.text = text
        self.sentAt = sentAt
        self.direction = direction
        self.receipt = receipt
        self.imageURL = imageURL
        self.isSticker = isSticker
        self.replyPreview = replyPreview
        self.reactions = reactions
        self.deliveryState = deliveryState
    }
}

struct MessageDay: Identifiable, Hashable {
    let date: Date
    let messages: [Message]

    var id: Date { date }
}
