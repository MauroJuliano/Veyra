import Foundation

struct VoiceCall: Identifiable, Equatable, Sendable {
    let id: UUID
    let participantID: UUID?
    let participantName: String
    let participantAvatarURL: URL?
    let direction: VoiceCallDirection
    let createdAt: Date

    init(
        id: UUID = UUID(),
        participantID: UUID?,
        participantName: String,
        participantAvatarURL: URL?,
        direction: VoiceCallDirection = .outgoing,
        createdAt: Date = .now
    ) {
        self.id = id
        self.participantID = participantID
        self.participantName = participantName
        self.participantAvatarURL = participantAvatarURL
        self.direction = direction
        self.createdAt = createdAt
    }
}

enum VoiceCallDirection: Hashable, Sendable {
    case incoming
    case outgoing
}

enum VoiceCallState: Equatable, Sendable {
    case idle
    case ringing
    case calling
    case connecting
    case connected
    case ended
    case failed
}

struct VoiceCallHistory: Identifiable, Hashable, Sendable {
    let id: UUID
    let direction: VoiceCallDirection
    let status: VoiceCallHistoryStatus
    let startedAt: Date
    let answeredAt: Date?
    let endedAt: Date?

    var duration: TimeInterval? {
        guard let answeredAt, let endedAt else { return nil }
        return max(0, endedAt.timeIntervalSince(answeredAt))
    }
}

enum VoiceCallHistoryStatus: String, Hashable, Sendable {
    case ringing
    case accepted
    case declined
    case ended
    case missed
}
