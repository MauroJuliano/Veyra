final class AppDependencies {
    let conversations: any ConversationRepository
    let contacts: any ContactRepository
    let remoteChat: (any RemoteChatRepository)?

    init(
        conversations: any ConversationRepository,
        contacts: any ContactRepository,
        remoteChat: (any RemoteChatRepository)? = nil
    ) {
        self.conversations = conversations
        self.contacts = contacts
        self.remoteChat = remoteChat
    }

    convenience init() {
        let conversations: any ConversationRepository
        do {
            conversations = try SwiftDataConversationRepository()
        } catch {
            conversations = InMemoryConversationRepository()
        }
        let remoteChat: (any RemoteChatRepository)?
        if let configuration = try? SupabaseConfiguration.from() {
            remoteChat = SupabaseChatRepository(client: SupabaseClientProvider.make(configuration: configuration))
        } else {
            remoteChat = nil
        }
        self.init(
            conversations: conversations,
            contacts: InMemoryContactRepository(),
            remoteChat: remoteChat
        )
    }
}
