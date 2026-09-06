import Foundation
import Testing
@testable import Veyra

@MainActor
struct VoiceCallCoordinatorTests {
    private let call = VoiceCall(
        participantID: UUID(),
        participantName: "Martha Nielsen",
        participantAvatarURL: nil
    )

    @Test func startsAnOutgoingCallOnlyOnce() {
        let coordinator = VoiceCallCoordinator(call: call)
        coordinator.start()
        coordinator.start()
        #expect(coordinator.state == .calling)
    }

    @Test func connectsAndTracksTheStartDate() {
        let coordinator = VoiceCallCoordinator(call: call)
        let connectedAt = Date(timeIntervalSince1970: 100)
        coordinator.start()
        coordinator.markConnecting()
        coordinator.markConnected(at: connectedAt)
        #expect(coordinator.state == .connected)
        #expect(coordinator.connectedAt == connectedAt)
    }

    @Test func togglesLocalAudioControls() {
        let coordinator = VoiceCallCoordinator(call: call)
        coordinator.start()
        coordinator.toggleMute()
        coordinator.toggleSpeaker()
        #expect(coordinator.isMuted)
        #expect(coordinator.isSpeakerEnabled)
    }

    @Test func endingIsTerminal() {
        let coordinator = VoiceCallCoordinator(call: call)
        let endedAt = Date(timeIntervalSince1970: 200)
        coordinator.start()
        coordinator.end(at: endedAt)
        coordinator.markConnected()
        coordinator.toggleMute()
        #expect(coordinator.state == .ended)
        #expect(coordinator.endedAt == endedAt)
        #expect(!coordinator.isMuted)
    }
}
