import Foundation
import Observation

@MainActor
@Observable
final class IncomingCallCoordinator {
    var incomingCall: VoiceCall?
    private let repository: (any CallRepository)?

    init(repository: (any CallRepository)?) {
        self.repository = repository
    }

    func observe() async {
        guard let repository else { return }
        do {
            let events = try await repository.activeCallEvents()
            for await calls in events {
                guard !Task.isCancelled else { return }
                incomingCall = calls.first { $0.call.direction == .incoming }?.call
            }
        } catch is CancellationError {
            return
        } catch {
            incomingCall = nil
        }
    }
}
