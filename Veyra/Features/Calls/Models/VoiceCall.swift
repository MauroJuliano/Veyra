import Foundation

struct VoiceCall: Identifiable, Equatable, Sendable {
    let id: UUID
    let participantID: UUID?
    let participantName: String
    let participantAvatarURL: URL?

    init(id: UUID = UUID(), participantID: UUID?, participantName: String, participantAvatarURL: URL?) {
        self.id = id
        self.participantID = participantID
        self.participantName = participantName
        self.participantAvatarURL = participantAvatarURL
    }
}

enum VoiceCallState: Equatable, Sendable {
    case idle
    case calling
    case connecting
    case connected
    case ended
    case failed
}
