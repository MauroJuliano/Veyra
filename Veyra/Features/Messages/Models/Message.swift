import Foundation

struct Message: Identifiable, Hashable {
    enum Direction: Hashable {
        case incoming
        case outgoing
    }

    enum Receipt: Hashable {
        case sent
        case read
    }

    let id: UUID
    let text: String
    let sentAt: Date
    let direction: Direction
    let receipt: Receipt

    init(id: UUID = UUID(), text: String, sentAt: Date = .now, direction: Direction, receipt: Receipt = .sent) {
        self.id = id
        self.text = text
        self.sentAt = sentAt
        self.direction = direction
        self.receipt = receipt
    }
}

struct MessageDay: Identifiable, Hashable {
    let date: Date
    let messages: [Message]

    var id: Date { date }
}
