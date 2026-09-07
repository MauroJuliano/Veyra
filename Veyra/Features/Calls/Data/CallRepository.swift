import Foundation

protocol CallRepository: Sendable {
    func startCall(to participant: VoiceCall) async throws -> VoiceCall
    func answerCall(id: UUID, accept: Bool) async throws
    func endCall(id: UUID) async throws
    func activeCallEvents() async throws -> AsyncStream<[VoiceCallUpdate]>
    func fetchCallHistory(with participantID: UUID) async throws -> [VoiceCallHistory]
    func sendSignal(_ signal: CallSignal, callID: UUID) async throws
    func signalEvents(callID: UUID) async throws -> AsyncStream<[CallSignalEnvelope]>
}

struct VoiceCallUpdate: Equatable, Sendable {
    let call: VoiceCall
    let state: VoiceCallState
    let answeredAt: Date?
}

enum CallSignal: Equatable, Sendable {
    case offer(String)
    case answer(String)
    case ice(candidate: String, sdpMid: String?, sdpMLineIndex: Int32)
}

struct CallSignalEnvelope: Equatable, Sendable, Identifiable {
    let id: Int64
    let signal: CallSignal
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
