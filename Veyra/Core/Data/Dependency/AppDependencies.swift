final class AppDependencies {
    let conversations: any ConversationRepository
    let contacts: any ContactRepository
    let remoteChat: (any RemoteChatRepository)?
    let messageCache: any MessageCacheRepository

    init(
        conversations: any ConversationRepository,
        contacts: any ContactRepository,
        remoteChat: (any RemoteChatRepository)? = nil,
        messageCache: any MessageCacheRepository = InMemoryMessageCacheRepository()
    ) {
        self.conversations = conversations
        self.contacts = contacts
        self.remoteChat = remoteChat
        self.messageCache = messageCache
    }

    convenience init() {
        let conversations: any ConversationRepository
        let contacts: any ContactRepository
        let messageCache: any MessageCacheRepository
        do {
            let swiftData = try SwiftDataConversationRepository()
            conversations = swiftData
            contacts = swiftData
            messageCache = swiftData
        } catch {
            conversations = InMemoryConversationRepository()
            contacts = InMemoryContactRepository()
            messageCache = InMemoryMessageCacheRepository()
        }
        let remoteChat: (any RemoteChatRepository)?
        if let configuration = try? SupabaseConfiguration.from() {
            remoteChat = SupabaseChatRepository(client: SupabaseClientProvider.make(configuration: configuration))
        } else {
            remoteChat = nil
        }
        self.init(
            conversations: conversations,
            contacts: contacts,
            remoteChat: remoteChat,
            messageCache: messageCache
        )
    }
}
