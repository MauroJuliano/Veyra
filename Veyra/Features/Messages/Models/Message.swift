import Foundation

struct Message: Identifiable, Hashable {
    enum Direction: Hashable {
        case incoming
        case outgoing
    }

    let id: UUID
    let text: String
    let sentAt: Date
    let direction: Direction

    init(id: UUID = UUID(), text: String, sentAt: Date = .now, direction: Direction) {
        self.id = id
        self.text = text
        self.sentAt = sentAt
        self.direction = direction
    }
}

struct MessageDay: Identifiable, Hashable {
    let date: Date
    let messages: [Message]

    var id: Date { date }
}
