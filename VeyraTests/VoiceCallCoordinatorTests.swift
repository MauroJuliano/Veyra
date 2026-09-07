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

    @Test func startsAnOutgoingCallOnlyOnce() async {
        let coordinator = VoiceCallCoordinator(call: call)
        await coordinator.start()
        await coordinator.start()
        #expect(coordinator.state == .calling)
    }

    @Test func connectsAndTracksTheStartDate() async {
        let coordinator = VoiceCallCoordinator(call: call)
        let connectedAt = Date(timeIntervalSince1970: 100)
        await coordinator.start()
        coordinator.markConnecting()
        coordinator.markConnected(at: connectedAt)
        #expect(coordinator.state == .connected)
        #expect(coordinator.connectedAt == connectedAt)
    }

    @Test func togglesLocalAudioControls() async {
        let coordinator = VoiceCallCoordinator(call: call)
        await coordinator.start()
        coordinator.toggleMute()
        coordinator.toggleSpeaker()
        #expect(coordinator.isMuted)
        #expect(coordinator.isSpeakerEnabled)
    }

    @Test func endingIsTerminal() async {
        let coordinator = VoiceCallCoordinator(call: call)
        let endedAt = Date(timeIntervalSince1970: 200)
        await coordinator.start()
        coordinator.end(at: endedAt)
        coordinator.markConnected()
        coordinator.toggleMute()
        #expect(coordinator.state == .ended)
        #expect(coordinator.endedAt == endedAt)
        #expect(!coordinator.isMuted)
    }
}
