import Foundation
@preconcurrency import Supabase

protocol RemoteChatRepository: Sendable {
    func fetchConversations() async throws -> [Conversation]
    func startConversation(withEmail email: String) async throws -> Conversation
    func startConversation(with contact: Contact) async throws -> Conversation
    func fetchMessages(conversationID: UUID) async throws -> [Message]
    func sendMessage(_ text: String, conversationID: UUID) async throws -> Message
    func messageEvents(conversationID: UUID) async throws -> AsyncStream<Void>
    func conversationEvents() async throws -> AsyncStream<ConversationEvent>
    func markConversationRead(conversationID: UUID) async throws
    func deleteMessage(id: UUID) async throws
    func deleteConversation(id: UUID) async throws
    func fetchContacts() async throws -> [Contact]
}

enum ConversationEvent: Sendable {
    case contentChanged
    case presenceChanged(Set<UUID>)
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

    func startConversation(with contact: Contact) async throws -> Conversation {
        if let conversationID = contact.conversationID {
            return Conversation(
                id: conversationID,
                participantID: contact.id,
                participantName: contact.name,
                lastMessage: "",
                updatedAt: .now,
                isOnline: contact.isOnline
            )
        }

        let conversationID: UUID = try await client
            .rpc("start_direct_conversation_with_user", params: ["target_user_id": contact.id])
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

    func markConversationRead(conversationID: UUID) async throws {
        let currentUserID = try await client.auth.session.user.id
        try await client
            .from("conversation_members")
            .update(ReadStateRow(lastReadAt: .now))
            .eq("conversation_id", value: conversationID)
            .eq("user_id", value: currentUserID)
            .execute()
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

    func deleteMessage(id: UUID) async throws {
        try await client
            .from("messages")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func deleteConversation(id: UUID) async throws {
        try await client
            .rpc("delete_conversation", params: ["target_conversation_id": id])
            .execute()
    }

    func fetchContacts() async throws -> [Contact] {
        let rows: [ContactRow] = try await client
            .rpc("list_my_contacts")
            .execute()
            .value
        return rows.map(\.contact)
    }

    func messageEvents(conversationID: UUID) async throws -> AsyncStream<Void> {
        let channel = client.channel("conversation:\(conversationID.uuidString)")
        // Supabase does not reliably apply column filters to DELETE payloads.
        // RLS still limits events to the signed-in user's conversations, and
        // the timeline refetch below keeps this conversation consistent.
        let changes = channel.postgresChange(AnyAction.self, table: "messages")

        try await channel.subscribeWithError()

        return AsyncStream { continuation in
            let observation = Task {
                for await _ in changes {
                    guard !Task.isCancelled else { break }
                    continuation.yield(())
                }
                continuation.finish()
            }

            continuation.onTermination = { [client] _ in
                observation.cancel()
                Task { await client.removeChannel(channel) }
            }
        }
    }

    func conversationEvents() async throws -> AsyncStream<ConversationEvent> {
        let currentUserID = try await client.auth.session.user.id
        let channel = client.channel("veyra:online-users") { config in
            config.presence = PresenceJoinConfig(key: currentUserID.uuidString)
        }
        let messageChanges = channel.postgresChange(AnyAction.self, table: "messages")
        let membershipChanges = channel.postgresChange(AnyAction.self, table: "conversation_members")
        let presenceChanges = channel.presenceChange()

        try await channel.subscribeWithError()
        try await channel.track(PresencePayload(userID: currentUserID))

        return AsyncStream { continuation in
            let messagesTask = Task {
                for await _ in messageChanges {
                    guard !Task.isCancelled else { break }
                    continuation.yield(.contentChanged)
                }
            }
            let membershipsTask = Task {
                for await _ in membershipChanges {
                    guard !Task.isCancelled else { break }
                    continuation.yield(.contentChanged)
                }
            }
            let presenceTask = Task {
                var onlineUserIDs = Set<UUID>()
                for await change in presenceChanges {
                    guard !Task.isCancelled else { break }
                    for key in change.joins.keys {
                        if let userID = UUID(uuidString: key) { onlineUserIDs.insert(userID) }
                    }
                    for key in change.leaves.keys {
                        if let userID = UUID(uuidString: key) { onlineUserIDs.remove(userID) }
                    }
                    continuation.yield(.presenceChanged(onlineUserIDs))
                }
            }

            continuation.onTermination = { [client] _ in
                messagesTask.cancel()
                membershipsTask.cancel()
                presenceTask.cancel()
                Task { await client.removeChannel(channel) }
            }
        }
    }
}

enum ChatRepositoryError: LocalizedError {
    case conversationNotFound
    var errorDescription: String? { "The conversation could not be loaded." }
}

private struct ConversationRow: Decodable {
    let conversationID: UUID
    let participantID: UUID
    let participantName: String
    let lastMessage: String
    let updatedAt: Date
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case participantID = "participant_id"
        case participantName = "participant_name"
        case lastMessage = "last_message"
        case updatedAt = "updated_at"
        case unreadCount = "unread_count"
    }

    var conversation: Conversation {
        Conversation(id: conversationID, participantID: participantID, participantName: participantName, lastMessage: lastMessage, updatedAt: updatedAt, unreadCount: unreadCount)
    }
}

private struct ContactRow: Decodable {
    let contactID: UUID
    let displayName: String
    let conversationID: UUID?

    enum CodingKeys: String, CodingKey {
        case contactID = "contact_id"
        case displayName = "display_name"
        case conversationID = "conversation_id"
    }

    var contact: Contact {
        Contact(id: contactID, name: displayName, conversationID: conversationID)
    }
}

private struct ReadStateRow: Encodable {
    let lastReadAt: Date

    enum CodingKeys: String, CodingKey {
        case lastReadAt = "last_read_at"
    }
}

private struct PresencePayload: Codable {
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
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
