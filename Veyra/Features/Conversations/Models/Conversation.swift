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
    let participantAvatarURL: URL?

    var lastActivityText: String {
        guard lastMessage.hasPrefix("[call]") else { return lastMessage }
        return switch String(lastMessage.dropFirst("[call]".count)) {
        case "incoming:declined": String(localized: "Declined incoming call")
        case "incoming:missed", "incoming:ringing": String(localized: "Missed incoming call")
        case "outgoing:declined": String(localized: "Declined outgoing call")
        case "outgoing:missed", "outgoing:ringing": String(localized: "Unanswered outgoing call")
        case "incoming:accepted", "incoming:ended": String(localized: "Incoming call")
        case "outgoing:accepted", "outgoing:ended": String(localized: "Outgoing call")
        default: String(localized: "Voice call")
        }
    }

    var lastActivityIsCall: Bool { lastMessage.hasPrefix("[call]") }

    init(id: UUID = UUID(), participantID: UUID? = nil, participantName: String, lastMessage: String, updatedAt: Date, unreadCount: Int = 0, isOnline: Bool = false, lastSeenAt: Date? = nil, lastMessageIsMine: Bool = false, lastMessageIsRead: Bool = false, participantAvatarURL: URL? = nil) {
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
        self.participantAvatarURL = participantAvatarURL
    }
}
