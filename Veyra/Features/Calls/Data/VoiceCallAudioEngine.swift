import Foundation

@MainActor
protocol VoiceCallAudioEngine: AnyObject {
    func startOutgoing(callID: UUID) async throws
    func startIncoming(callID: UUID) async throws
    func setMuted(_ isMuted: Bool)
    func setSpeakerEnabled(_ isEnabled: Bool) throws
    func stop()
}
