import Foundation
@preconcurrency import Supabase

protocol RemoteChatRepository: Sendable {
    func fetchConversations() async throws -> [Conversation]
    func startConversation(withEmail email: String) async throws -> Conversation
    func fetchMessages(conversationID: UUID) async throws -> [Message]
    func sendMessage(_ text: String, conversationID: UUID) async throws -> Message
}

final class SupabaseChatRepository: RemoteChatRepository, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    func fetchConversations() async throws -> [Conversation] {
        let rows: [ConversationRow] = try await client
            .rpc("list_my_conversations")
            .execute()
            .value
        return rows.map(\.conversation)
    }

    func startConversation(withEmail email: String) async throws -> Conversation {
        let conversationID: UUID = try await client
            .rpc("start_direct_conversation", params: ["target_email": email])
            .execute()
            .value
        guard let conversation = try await fetchConversations().first(where: { $0.id == conversationID }) else {
            throw ChatRepositoryError.conversationNotFound
        }
        return conversation
    }

    func fetchMessages(conversationID: UUID) async throws -> [Message] {
        let currentUserID = try await client.auth.session.user.id
        let rows: [MessageRow] = try await client
            .from("messages")
            .select()
            .eq("conversation_id", value: conversationID)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows.map { $0.message(currentUserID: currentUserID) }
    }

    func sendMessage(_ text: String, conversationID: UUID) async throws -> Message {
        let currentUserID = try await client.auth.session.user.id
        let payload = NewMessageRow(conversationID: conversationID, senderID: currentUserID, body: text)
        let row: MessageRow = try await client
            .from("messages")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return row.message(currentUserID: currentUserID)
    }
}

enum ChatRepositoryError: LocalizedError {
    case conversationNotFound
    var errorDescription: String? { "The conversation could not be loaded." }
}

private struct ConversationRow: Decodable {
    let conversationID: UUID
    let participantName: String
    let lastMessage: String
    let updatedAt: Date
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case participantName = "participant_name"
        case lastMessage = "last_message"
        case updatedAt = "updated_at"
        case unreadCount = "unread_count"
    }

    var conversation: Conversation {
        Conversation(id: conversationID, participantName: participantName, lastMessage: lastMessage, updatedAt: updatedAt, unreadCount: unreadCount)
    }
}

private struct MessageRow: Decodable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case createdAt = "created_at"
    }

    func message(currentUserID: UUID) -> Message {
        Message(id: id, text: body, sentAt: createdAt, direction: senderID == currentUserID ? .outgoing : .incoming)
    }
}

private struct NewMessageRow: Encodable {
    let conversationID: UUID
    let senderID: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case body
    }
}
