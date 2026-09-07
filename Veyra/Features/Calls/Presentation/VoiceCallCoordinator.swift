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

    private(set) var call: VoiceCall
    private(set) var errorMessage: String?
    private let repository: (any CallRepository)?
    private var eventsTask: Task<Void, Never>?
    private var hasObservedActiveCall = false

    init(call: VoiceCall, repository: (any CallRepository)? = nil) {
        self.call = call
        self.repository = repository
        state = call.direction == .incoming ? .ringing : .idle
    }

    func start() async {
        guard state == .idle else {
            if state == .ringing { observeEvents() }
            return
        }
        state = .calling
        guard let repository else { return }
        do {
            call = try await repository.startCall(to: call)
            observeEvents()
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
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

    func answer() async {
        guard state == .ringing, let repository else { return }
        state = .connecting
        do {
            try await repository.answerCall(id: call.id, accept: true)
            observeEvents()
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }

    func decline() async {
        guard state == .ringing else { return }
        do {
            try await repository?.answerCall(id: call.id, accept: false)
        } catch {
            errorMessage = error.localizedDescription
        }
        end()
    }

    func end(at date: Date = .now) {
        guard state != .ended else { return }
        let callID = call.id
        let repository = repository
        eventsTask?.cancel()
        endedAt = date
        state = .ended
        if repository != nil {
            Task { try? await repository?.endCall(id: callID) }
        }
    }

    private func observeEvents() {
        guard eventsTask == nil, let repository else { return }
        eventsTask = Task { [weak self] in
            do {
                let events = try await repository.activeCallEvents()
                for await calls in events {
                    guard let self, !Task.isCancelled else { return }
                    if let update = calls.first(where: { $0.call.id == self.call.id }) {
                        self.hasObservedActiveCall = true
                        self.call = update.call
                        switch update.state {
                        case .connected:
                            self.markConnected(at: update.answeredAt ?? .now)
                        case .ringing:
                            self.state = .ringing
                        case .calling:
                            self.state = .calling
                        default:
                            break
                        }
                    } else if self.hasObservedActiveCall {
                        self.end()
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                self.errorMessage = error.localizedDescription
                self.state = .failed
            }
        }
    }
}
