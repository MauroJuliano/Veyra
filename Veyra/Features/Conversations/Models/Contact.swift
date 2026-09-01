import Foundation

struct Contact: Identifiable, Hashable {
    let id: UUID
    let name: String
    let isOnline: Bool
    let conversationID: UUID?

    init(id: UUID = UUID(), name: String, isOnline: Bool = false, conversationID: UUID? = nil) {
        self.id = id
        self.name = name
        self.isOnline = isOnline
        self.conversationID = conversationID
    }
}
