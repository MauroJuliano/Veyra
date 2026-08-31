final class AppDependencies {
    let conversations: any ConversationRepository
    let contacts: any ContactRepository

    init(
        conversations: any ConversationRepository = InMemoryConversationRepository(),
        contacts: any ContactRepository = InMemoryContactRepository()
    ) {
        self.conversations = conversations
        self.contacts = contacts
    }
}
