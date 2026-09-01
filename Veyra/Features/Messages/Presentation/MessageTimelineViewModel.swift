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
    private(set) var isParticipantTyping = false
    private(set) var errorMessage: String?
    private var typingStopTask: Task<Void, Never>?
    private var participantTypingTimeoutTask: Task<Void, Never>?

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

            for await event in events {
                guard !Task.isCancelled else { return }
                switch event {
                case .contentChanged:
                    await refreshMessages(using: repository)
                    try await repository.markConversationRead(conversationID: conversationID)
                case let .typingChanged(isTyping):
                    updateParticipantTyping(isTyping)
                }
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
            typingStopTask?.cancel()
            try await repository.setTyping(false, conversationID: conversationID)
            let message = try await repository.sendMessage(text, conversationID: conversationID)
            appendIfNeeded(message)
            draft = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func draftDidChange() {
        guard repository != nil else { return }
        typingStopTask?.cancel()

        let hasText = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        Task { try? await repository?.setTyping(hasText, conversationID: conversationID) }
        guard hasText else { return }

        typingStopTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self else { return }
            try? await self.repository?.setTyping(false, conversationID: self.conversationID)
        }
    }

    @MainActor
    func stopTyping() async {
        typingStopTask?.cancel()
        try? await repository?.setTyping(false, conversationID: conversationID)
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

    @MainActor
    private func updateParticipantTyping(_ isTyping: Bool) {
        participantTypingTimeoutTask?.cancel()
        isParticipantTyping = isTyping
        guard isTyping else { return }

        participantTypingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.isParticipantTyping = false
        }
    }
}
