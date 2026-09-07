import Foundation

protocol CallRepository: Sendable {
    func startCall(to participant: VoiceCall) async throws -> VoiceCall
    func answerCall(id: UUID, accept: Bool) async throws
    func endCall(id: UUID) async throws
    func activeCallEvents() async throws -> AsyncStream<[VoiceCallUpdate]>
}

struct VoiceCallUpdate: Equatable, Sendable {
    let call: VoiceCall
    let state: VoiceCallState
    let answeredAt: Date?
}

enum CallRepositoryError: LocalizedError, Equatable {
    case missingParticipant

    var errorDescription: String? {
        switch self {
        case .missingParticipant:
            String(localized: "This user cannot receive calls right now.")
        }
    }
}
