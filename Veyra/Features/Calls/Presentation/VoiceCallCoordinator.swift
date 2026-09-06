import Foundation
import Observation

@MainActor
@Observable
final class VoiceCallCoordinator {
    private(set) var state: VoiceCallState = .idle
    private(set) var connectedAt: Date?
    private(set) var endedAt: Date?
    private(set) var isMuted = false
    private(set) var isSpeakerEnabled = false

    let call: VoiceCall

    init(call: VoiceCall) {
        self.call = call
    }

    func start() {
        guard state == .idle else { return }
        state = .calling
    }

    func markConnecting() {
        guard state == .calling else { return }
        state = .connecting
    }

    func markConnected(at date: Date = .now) {
        guard state == .calling || state == .connecting else { return }
        connectedAt = date
        state = .connected
    }

    func toggleMute() {
        guard state != .ended else { return }
        isMuted.toggle()
    }

    func toggleSpeaker() {
        guard state != .ended else { return }
        isSpeakerEnabled.toggle()
    }

    func fail() {
        guard state != .ended else { return }
        state = .failed
    }

    func end(at date: Date = .now) {
        guard state != .ended else { return }
        endedAt = date
        state = .ended
    }
}
