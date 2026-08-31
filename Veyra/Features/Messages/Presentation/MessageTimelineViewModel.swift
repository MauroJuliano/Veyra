import Foundation
import Observation

@Observable
final class MessageTimelineViewModel {
    private(set) var messages: [Message]
    var draft = ""

    init(messages: [Message]) {
        self.messages = messages.sorted { $0.sentAt < $1.sentAt }
    }

    var days: [MessageDay] {
        Dictionary(grouping: messages) { Calendar.current.startOfDay(for: $0.sentAt) }
            .map { MessageDay(date: $0.key, messages: $0.value.sorted { $0.sentAt < $1.sentAt }) }
            .sorted { $0.date < $1.date }
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(Message(text: text, direction: .outgoing))
        draft = ""
    }
}
