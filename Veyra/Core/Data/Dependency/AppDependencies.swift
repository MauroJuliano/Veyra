final class AppDependencies {
    let conversations: any ConversationRepository
    let contacts: any ContactRepository
    let remoteChat: (any RemoteChatRepository)?
    let calls: (any CallRepository)?
    let messageCache: any MessageCacheRepository

    init(
        conversations: any ConversationRepository,
        contacts: any ContactRepository,
        remoteChat: (any RemoteChatRepository)? = nil,
        calls: (any CallRepository)? = nil,
        messageCache: any MessageCacheRepository = InMemoryMessageCacheRepository()
    ) {
        self.conversations = conversations
        self.contacts = contacts
        self.remoteChat = remoteChat
        self.calls = calls
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
        let calls: (any CallRepository)?
        if let configuration = try? SupabaseConfiguration.from() {
            let client = SupabaseClientProvider.make(configuration: configuration)
            remoteChat = SupabaseChatRepository(client: client)
            calls = SupabaseCallRepository(client: client)
        } else {
            remoteChat = nil
            calls = nil
        }
        self.init(
            conversations: conversations,
            contacts: contacts,
            remoteChat: remoteChat,
            calls: calls,
            messageCache: messageCache
        )
    }
}
