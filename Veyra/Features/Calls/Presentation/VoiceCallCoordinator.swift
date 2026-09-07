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
    private let audioEngine: (any VoiceCallAudioEngine)?
    private let unansweredTimeout: Duration
    private var eventsTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var hasObservedActiveCall = false
    private var hasPersistedCall = false

    init(
        call: VoiceCall,
        repository: (any CallRepository)? = nil,
        audioEngine: (any VoiceCallAudioEngine)? = nil,
        unansweredTimeout: Duration = .seconds(30)
    ) {
        self.call = call
        self.repository = repository
        self.audioEngine = audioEngine
        self.unansweredTimeout = unansweredTimeout
        state = call.direction == .incoming ? .ringing : .idle
    }

    func start() async {
        guard state == .idle else {
            if state == .ringing {
                hasPersistedCall = repository != nil
                observeEvents()
                scheduleUnansweredTimeout()
                startHeartbeat()
            }
            return
        }
        state = .calling
        guard let repository else { return }
        do {
            call = try await repository.startCall(to: call)
            hasPersistedCall = true
            observeEvents()
            scheduleUnansweredTimeout()
            startHeartbeat()
            try await audioEngine?.startOutgoing(callID: call.id)
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
            finishPersistedCallIfNeeded()
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
        timeoutTask?.cancel()
        timeoutTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    func toggleMute() {
        guard state != .ended else { return }
        isMuted.toggle()
        audioEngine?.setMuted(isMuted)
    }

    func toggleSpeaker() {
        guard state != .ended else { return }
        do {
            let newValue = !isSpeakerEnabled
            try audioEngine?.setSpeakerEnabled(newValue)
            isSpeakerEnabled = newValue
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fail() {
        guard state != .ended else { return }
        state = .failed
        timeoutTask?.cancel()
        audioEngine?.stop()
        finishPersistedCallIfNeeded()
    }

    func answer() async {
        guard state == .ringing, let repository else { return }
        state = .connecting
        do {
            try await repository.answerCall(id: call.id, accept: true)
            observeEvents()
            startHeartbeat()
            try await audioEngine?.startIncoming(callID: call.id)
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
            finishPersistedCallIfNeeded()
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
        timeoutTask?.cancel()
        timeoutTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        audioEngine?.stop()
        endedAt = date
        state = .ended
        if repository != nil, hasPersistedCall {
            hasPersistedCall = false
            Task { try? await repository?.endCall(id: callID) }
        }
    }

    func abandonIfNeeded() {
        guard state != .ended && state != .failed else { return }
        end()
    }

    private func scheduleUnansweredTimeout() {
        timeoutTask?.cancel()
        let timeout = unansweredTimeout
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: timeout)
                guard let self, self.state == .calling || self.state == .ringing || self.state == .connecting else { return }
                self.end()
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    private func finishPersistedCallIfNeeded() {
        guard hasPersistedCall, let repository else { return }
        heartbeatTask?.cancel()
        heartbeatTask = nil
        hasPersistedCall = false
        let callID = call.id
        Task { try? await repository.endCall(id: callID) }
    }

    private func startHeartbeat() {
        guard heartbeatTask == nil, let repository else { return }
        let callID = call.id
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await repository.heartbeatCall(id: callID)
                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    return
                }
            }
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
