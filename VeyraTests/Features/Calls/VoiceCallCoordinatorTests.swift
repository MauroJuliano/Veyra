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

    @Test func unansweredCallEndsAfterTimeout() async throws {
        let repository = CallRepositorySpy()
        let coordinator = VoiceCallCoordinator(
            call: call,
            repository: repository,
            audioEngine: VoiceCallAudioEngineSpy(),
            unansweredTimeout: .milliseconds(20)
        )

        await coordinator.start()
        try await waitUntil {
            let endCallCount = await repository.endCallCount
            return coordinator.state == .ended && endCallCount == 1
        }

        #expect(coordinator.state == .ended)
        #expect(await repository.endCallCount == 1)
    }

    @Test func connectedCallCancelsUnansweredTimeout() async throws {
        let repository = CallRepositorySpy()
        let coordinator = VoiceCallCoordinator(
            call: call,
            repository: repository,
            audioEngine: VoiceCallAudioEngineSpy(),
            unansweredTimeout: .milliseconds(20)
        )

        await coordinator.start()
        coordinator.markConnecting()
        coordinator.markConnected()
        try await Task.sleep(for: .milliseconds(60))

        #expect(coordinator.state == .connected)
        #expect(await repository.endCallCount == 0)
        coordinator.end()
    }

    @Test func leavingCallScreenEndsPersistedCall() async throws {
        let repository = CallRepositorySpy()
        let coordinator = VoiceCallCoordinator(
            call: call,
            repository: repository,
            audioEngine: VoiceCallAudioEngineSpy()
        )

        await coordinator.start()
        coordinator.abandonIfNeeded()
        try await waitUntil {
            await repository.endCallCount == 1
        }

        #expect(coordinator.state == .ended)
        #expect(await repository.endCallCount == 1)
    }

    @Test func audioSetupFailureEndsPersistedCall() async throws {
        let repository = CallRepositorySpy()
        let coordinator = VoiceCallCoordinator(
            call: call,
            repository: repository,
            audioEngine: VoiceCallAudioEngineSpy(shouldFailStart: true)
        )

        await coordinator.start()
        try await waitUntil {
            await repository.endCallCount == 1
        }

        #expect(coordinator.state == .failed)
        #expect(await repository.endCallCount == 1)
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while !(await condition()), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private actor CallRepositorySpy: CallRepository {
    private(set) var endCallCount = 0

    func startCall(to participant: VoiceCall) async throws -> VoiceCall {
        VoiceCall(
            id: UUID(),
            participantID: participant.participantID,
            participantName: participant.participantName,
            participantAvatarURL: participant.participantAvatarURL,
            direction: participant.direction
        )
    }

    func answerCall(id: UUID, accept: Bool) async throws {}
    func endCall(id: UUID) async throws { endCallCount += 1 }
    func heartbeatCall(id: UUID) async throws {}
    func activeCallEvents() async throws -> AsyncStream<[VoiceCallUpdate]> {
        AsyncStream { _ in }
    }
    func fetchCallHistory(with participantID: UUID) async throws -> [VoiceCallHistory] { [] }
    func sendSignal(_ signal: CallSignal, callID: UUID) async throws {}
    func signalEvents(callID: UUID) async throws -> AsyncStream<[CallSignalEnvelope]> {
        AsyncStream { _ in }
    }
}

@MainActor
private final class VoiceCallAudioEngineSpy: VoiceCallAudioEngine {
    let shouldFailStart: Bool

    init(shouldFailStart: Bool = false) {
        self.shouldFailStart = shouldFailStart
    }

    func startOutgoing(callID: UUID) async throws {
        if shouldFailStart { throw VoiceCallAudioEngineSpyError.startFailed }
    }

    func startIncoming(callID: UUID) async throws {
        if shouldFailStart { throw VoiceCallAudioEngineSpyError.startFailed }
    }

    func setMuted(_ isMuted: Bool) {}
    func setSpeakerEnabled(_ isEnabled: Bool) throws {}
    func stop() {}
}

private enum VoiceCallAudioEngineSpyError: Error {
    case startFailed
}
