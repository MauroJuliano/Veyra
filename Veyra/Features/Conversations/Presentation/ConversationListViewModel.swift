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
        conversations = remoteRepository == nil ? repository.fetchConversations() : []
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
            $0.participantName.localizedStandardContains(query) || $0.lastMessage.localizedStandardContains(query)
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
            conversations = applyingPresence(to: try await remoteRepository.fetchConversations())
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func observeConversations() async {
        guard let remoteRepository else { return }
        do {
            let events = try await remoteRepository.conversationEvents()
            await load()
            for await event in events {
                guard !Task.isCancelled else { return }
                switch event {
                case .contentChanged:
                    conversations = applyingPresence(to: try await remoteRepository.fetchConversations())
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
            conversations = try await remoteRepository.fetchConversations()
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
            return
        }
        do {
            try await remoteRepository.deleteConversation(id: conversation.id)
            conversations.removeAll { $0.id == conversation.id }
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
                lastSeenAt: conversation.lastSeenAt
            )
        }
    }
}
