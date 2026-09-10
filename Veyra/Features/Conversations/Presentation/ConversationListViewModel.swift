import Foundation
import Observation

@Observable
final class ConversationListViewModel {
    private let repository: any ConversationRepository
    private let remoteRepository: (any RemoteChatRepository)?
    private(set) var conversations: [Conversation]
    var searchText = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(repository: any ConversationRepository = InMemoryConversationRepository(), remoteRepository: (any RemoteChatRepository)? = nil) {
        self.repository = repository
        self.remoteRepository = remoteRepository
        conversations = repository.fetchConversations()
    }

    convenience init(conversations: [Conversation]) {
        self.init(repository: InMemoryConversationRepository(conversations: conversations))
    }

    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    var filteredConversations: [Conversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return conversations }
        return conversations.filter {
            $0.participantName.localizedStandardContains(query) || $0.lastActivityText.localizedStandardContains(query)
        }
    }

    var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var chatRepository: (any RemoteChatRepository)? { remoteRepository }

    func add(_ conversation: Conversation) {
        repository.save(conversation)
        conversations = repository.fetchConversations()
    }

    @MainActor
    func load() async {
        guard let remoteRepository else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let remoteConversations = applyingPresence(to: try await remoteRepository.fetchConversations())
            remoteConversations.forEach(repository.save)
            conversations = remoteConversations
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func observeConversations() async {
        guard let remoteRepository else { return }
        await load()
        do {
            let events = try await remoteRepository.conversationEvents()
            for await event in events {
                guard !Task.isCancelled else { return }
                switch event {
                case .contentChanged:
                    let remoteConversations = applyingPresence(to: try await remoteRepository.fetchConversations())
                    remoteConversations.forEach(repository.save)
                    conversations = remoteConversations
                case .presenceChanged:
                    break
                }
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func startConversation(email: String) async -> Conversation? {
        guard let remoteRepository else { return nil }
        isLoading = true
        defer { isLoading = false }
        do {
            let conversation = try await remoteRepository.startConversation(withEmail: email)
            let remoteConversations = try await remoteRepository.fetchConversations()
            remoteConversations.forEach(repository.save)
            conversations = remoteConversations
            errorMessage = nil
            return conversation
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @MainActor
    func startConversation(user: User) async -> Conversation? {
        guard let remoteRepository, let userID = user.participantID else { return nil }
        isLoading = true
        defer { isLoading = false }
        do {
            let contact = Contact(id: userID, name: user.participantName, avatarURL: user.participantAvatarURL)
            let conversation = try await remoteRepository.startConversation(with: contact)
            conversations = try await remoteRepository.fetchConversations()
            conversations.forEach(repository.save)
            errorMessage = nil
            return conversation
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @MainActor
    func delete(_ conversation: Conversation) async {
        guard let remoteRepository else {
            conversations.removeAll { $0.id == conversation.id }
            repository.deleteConversation(id: conversation.id)
            return
        }
        do {
            try await remoteRepository.deleteConversation(id: conversation.id)
            conversations.removeAll { $0.id == conversation.id }
            repository.deleteConversation(id: conversation.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    private func applyingPresence(to conversations: [Conversation]) -> [Conversation] {
        conversations.map { conversation in
            Conversation(
                id: conversation.id,
                participantID: conversation.participantID,
                participantName: conversation.participantName,
                lastMessage: conversation.lastMessage,
                updatedAt: conversation.updatedAt,
                unreadCount: conversation.unreadCount,
                isOnline: conversation.isOnline,
                lastSeenAt: conversation.lastSeenAt,
                lastMessageIsMine: conversation.lastMessageIsMine,
                lastMessageIsRead: conversation.lastMessageIsRead,
                participantAvatarURL: conversation.participantAvatarURL
            )
        }
    }
}
