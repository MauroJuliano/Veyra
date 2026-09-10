import Foundation

protocol RemoteChatRepository: Sendable {
    func fetchConversations() async throws -> [Conversation]
    func startConversation(withEmail email: String) async throws -> Conversation
    func startConversation(with contact: Contact) async throws -> Conversation
    func fetchMessages(conversationID: UUID, before: Date?, limit: Int) async throws -> [Message]
    func sendMessage(_ text: String, conversationID: UUID, replyingTo messageID: UUID?, clientMessageID: UUID?) async throws -> Message
    func sendImage(_ data: Data, conversationID: UUID) async throws -> Message
    func sendAudio(_ data: Data, duration: TimeInterval, conversationID: UUID) async throws -> Message
    func messageEvents(conversationID: UUID, participantID: UUID?) async throws -> AsyncStream<MessageEvent>
    func setTyping(_ isTyping: Bool, conversationID: UUID) async throws
    func conversationEvents() async throws -> AsyncStream<ConversationEvent>
    func markConversationRead(conversationID: UUID) async throws
    func deleteMessage(id: UUID) async throws
    func toggleReaction(_ emoji: String, messageID: UUID) async throws
    func deleteConversation(id: UUID) async throws
    func fetchContacts() async throws -> [Contact]
    func searchPeople(query: String) async throws -> [User]
    func fetchPublicProfile(userID: UUID) async throws -> User
    func fetchBlockRelationship(userID: UUID) async throws -> BlockRelationship
    func setUserBlocked(userID: UUID, isBlocked: Bool) async throws
    func fetchBlockedUsers() async throws -> [User]
    func canSendMessages(conversationID: UUID) async throws -> Bool
    func reportUser(userID: UUID, reason: String, details: String) async throws
    func fetchMyProfile() async throws -> UserProfile
    func updateMyProfile(displayName: String, username: String, bio: String, email: String) async throws -> UserProfile
    func updateMyAvatar(_ data: Data) async throws -> UserProfile
    func maintainPresence() async
    func registerPushToken(_ token: String) async throws
    func unregisterPushToken(_ token: String) async throws
}

enum ConversationEvent: Sendable {
    case contentChanged
    case presenceChanged(Set<UUID>)
}

enum MessageEvent: Sendable {
    case contentChanged
    case readReceiptChanged
    case typingChanged(Bool)
    case presenceChanged(isActive: Bool, lastSeenAt: Date?)
}
