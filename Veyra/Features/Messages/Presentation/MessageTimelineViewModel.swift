import Foundation
import Observation

@Observable
final class MessageTimelineViewModel {
    private let conversationID: UUID
    private let repository: (any RemoteChatRepository)?
    private(set) var messages: [Message]
    var draft = ""
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var errorMessage: String?

    init(conversationID: UUID = UUID(), repository: (any RemoteChatRepository)? = nil, messages: [Message]) {
        self.conversationID = conversationID
        self.repository = repository
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

    @MainActor
    func load() async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await repository.fetchMessages(conversationID: conversationID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let repository else {
            messages.append(Message(text: text, direction: .outgoing))
            draft = ""
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            let message = try await repository.sendMessage(text, conversationID: conversationID)
            messages.append(message)
            draft = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
