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
    func observeMessages() async {
        guard let repository else { return }

        do {
            // Subscribe before the initial fetch so messages sent during loading are not missed.
            let events = try await repository.messageEvents(conversationID: conversationID)
            await load()
            try await repository.markConversationRead(conversationID: conversationID)

            for await _ in events {
                guard !Task.isCancelled else { return }
                await refreshMessages(using: repository)
                try await repository.markConversationRead(conversationID: conversationID)
            }
        } catch is CancellationError {
            return
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
            appendIfNeeded(message)
            draft = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func delete(_ message: Message) async {
        guard message.direction == .outgoing else { return }
        guard let repository else {
            messages.removeAll { $0.id == message.id }
            return
        }
        do {
            try await repository.deleteMessage(id: message.id)
            messages.removeAll { $0.id == message.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refreshMessages(using repository: any RemoteChatRepository) async {
        do {
            messages = try await repository.fetchMessages(conversationID: conversationID)
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func appendIfNeeded(_ message: Message) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
        messages.sort { $0.sentAt < $1.sentAt }
    }
}
