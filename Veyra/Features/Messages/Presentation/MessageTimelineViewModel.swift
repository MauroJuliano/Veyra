import Foundation
import Observation

@Observable
final class MessageTimelineViewModel {
    private let conversationID: UUID
    private let participantID: UUID?
    private let repository: (any RemoteChatRepository)?
    private(set) var messages: [Message]
    var draft = ""
    private(set) var replyingTo: Message?
    private(set) var isLoading = false
    private(set) var isLoadingEarlier = false
    private(set) var hasEarlierMessages = true
    private(set) var isSending = false
    private(set) var isParticipantTyping = false
    private(set) var isParticipantActive: Bool
    private(set) var participantLastSeenAt: Date?
    private(set) var errorMessage: String?
    private var typingStopTask: Task<Void, Never>?
    private var participantTypingTimeoutTask: Task<Void, Never>?
    private let pageSize = 50

    init(conversationID: UUID = UUID(), participantID: UUID? = nil, isParticipantActive: Bool = false, participantLastSeenAt: Date? = nil, repository: (any RemoteChatRepository)? = nil, messages: [Message]) {
        self.conversationID = conversationID
        self.participantID = participantID
        self.isParticipantActive = isParticipantActive
        self.participantLastSeenAt = participantLastSeenAt
        self.repository = repository
        self.messages = messages.sorted { $0.sentAt < $1.sentAt }
        hasEarlierMessages = repository != nil
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
            let page = try await repository.fetchMessages(conversationID: conversationID, before: nil, limit: pageSize)
            messages = page.sorted { $0.sentAt < $1.sentAt }
            hasEarlierMessages = page.count == pageSize
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func loadEarlierMessages() async {
        guard let repository, hasEarlierMessages, !isLoadingEarlier, let oldest = messages.first else { return }
        isLoadingEarlier = true
        defer { isLoadingEarlier = false }
        do {
            let page = try await repository.fetchMessages(
                conversationID: conversationID,
                before: oldest.sentAt,
                limit: pageSize
            )
            merge(page)
            hasEarlierMessages = page.count == pageSize
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func observeMessages() async {
        guard let repository else { return }

        // The persisted timeline must load independently from Realtime. A
        // temporary WebSocket failure should only pause live updates, never
        // leave an existing conversation empty.
        await load()
        do {
            try await repository.markConversationRead(conversationID: conversationID)
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            let events = try await repository.messageEvents(conversationID: conversationID, participantID: participantID)

            for await event in events {
                guard !Task.isCancelled else { return }
                switch event {
                case .contentChanged:
                    await refreshMessages(using: repository)
                    try await repository.markConversationRead(conversationID: conversationID)
                case .readReceiptChanged:
                    await refreshMessages(using: repository)
                case let .typingChanged(isTyping):
                    updateParticipantTyping(isTyping)
                case let .presenceChanged(isActive, lastSeenAt):
                    isParticipantActive = isActive
                    participantLastSeenAt = lastSeenAt
                }
            }
        } catch is CancellationError {
            return
        } catch {
            // Keep the loaded timeline usable when live updates are
            // temporarily unavailable. Sending and manual navigation still
            // use the durable REST endpoints.
            return
        }
    }

    @MainActor
    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let repository else {
            let preview = replyingTo.map {
                Message.ReplyPreview(messageID: $0.id, text: $0.imageURL == nil ? $0.text : "Photo", isOwnMessage: $0.direction == .outgoing)
            }
            messages.append(Message(text: text, direction: .outgoing, replyPreview: preview))
            draft = ""
            replyingTo = nil
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            typingStopTask?.cancel()
            // Typing is an optional realtime enhancement and must never block
            // the durable message insert.
            try? await repository.setTyping(false, conversationID: conversationID)
            let message = try await repository.sendMessage(text, conversationID: conversationID, replyingTo: replyingTo?.id)
            appendIfNeeded(message)
            draft = ""
            replyingTo = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func sendImage(_ data: Data) async {
        guard let repository else { return }
        isSending = true
        defer { isSending = false }
        do {
            appendIfNeeded(try await repository.sendImage(data, conversationID: conversationID))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func sendSticker(_ sticker: String) async {
        guard let repository else {
            messages.append(Message(text: sticker, direction: .outgoing, isSticker: true))
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            appendIfNeeded(try await repository.sendMessage("[sticker]\(sticker)", conversationID: conversationID, replyingTo: replyingTo?.id))
            replyingTo = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func reportImageSelectionError(_ error: any Error) {
        errorMessage = error.localizedDescription
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
    func beginReply(to message: Message) {
        replyingTo = message
    }

    @MainActor
    func cancelReply() {
        replyingTo = nil
    }

    @MainActor
    func toggleReaction(_ emoji: String, on message: Message) async {
        guard let repository else { return }
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        let previousReactions = messages[index].reactions
        messages[index].reactions = toggledReactions(previousReactions, emoji: emoji)
        do {
            try await repository.toggleReaction(emoji, messageID: message.id)
            await refreshMessages(using: repository)
        } catch {
            if let currentIndex = messages.firstIndex(where: { $0.id == message.id }) {
                messages[currentIndex].reactions = previousReactions
            }
            errorMessage = error.localizedDescription
        }
    }

    private func toggledReactions(_ reactions: [Message.Reaction], emoji: String) -> [Message.Reaction] {
        var result = reactions
        if let index = result.firstIndex(where: { $0.emoji == emoji }) {
            let reaction = result[index]
            if reaction.isSelectedByCurrentUser {
                if reaction.count == 1 {
                    result.remove(at: index)
                } else {
                    result[index] = Message.Reaction(emoji: emoji, count: reaction.count - 1, isSelectedByCurrentUser: false)
                }
            } else {
                result[index] = Message.Reaction(emoji: emoji, count: reaction.count + 1, isSelectedByCurrentUser: true)
            }
        } else {
            result.append(Message.Reaction(emoji: emoji, count: 1, isSelectedByCurrentUser: true))
        }
        return result.sorted { $0.emoji < $1.emoji }
    }

    @MainActor
    private func refreshMessages(using repository: any RemoteChatRepository) async {
        do {
            let latest = try await repository.fetchMessages(conversationID: conversationID, before: nil, limit: pageSize)
            reconcileLatestPage(latest)
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

    private func merge(_ incoming: [Message]) {
        var indexed = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
        for message in incoming { indexed[message.id] = message }
        messages = indexed.values.sorted { $0.sentAt < $1.sentAt }
    }

    private func reconcileLatestPage(_ latest: [Message]) {
        guard latest.count == pageSize, let pageStart = latest.map(\.sentAt).min() else {
            messages = latest.sorted { $0.sentAt < $1.sentAt }
            hasEarlierMessages = false
            return
        }

        let latestIDs = Set(latest.map(\.id))
        messages.removeAll { $0.sentAt >= pageStart && !latestIDs.contains($0.id) }
        merge(latest)
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
