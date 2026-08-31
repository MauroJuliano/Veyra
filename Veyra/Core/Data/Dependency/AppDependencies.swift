final class AppDependencies {
    let conversations: any ConversationRepository
    let contacts: any ContactRepository

    init(
        conversations: any ConversationRepository,
        contacts: any ContactRepository
    ) {
        self.conversations = conversations
        self.contacts = contacts
    }

    convenience init() {
        let conversations: any ConversationRepository
        do {
            conversations = try SwiftDataConversationRepository()
        } catch {
            conversations = InMemoryConversationRepository()
        }
        self.init(
            conversations: conversations,
            contacts: InMemoryContactRepository()
        )
    }
}
