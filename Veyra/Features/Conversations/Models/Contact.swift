import Foundation

struct Contact: Identifiable, Hashable {
    let id: UUID
    let name: String
    let isOnline: Bool
    let conversationID: UUID?
    let avatarURL: URL?

    init(id: UUID = UUID(), name: String, isOnline: Bool = false, conversationID: UUID? = nil, avatarURL: URL? = nil) {
        self.id = id
        self.name = name
        self.isOnline = isOnline
        self.conversationID = conversationID
        self.avatarURL = avatarURL
    }
}
