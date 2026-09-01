import Foundation
@preconcurrency import Supabase

protocol RemoteChatRepository: Sendable {
    func fetchConversations() async throws -> [Conversation]
    func startConversation(withEmail email: String) async throws -> Conversation
    func fetchMessages(conversationID: UUID) async throws -> [Message]
    func sendMessage(_ text: String, conversationID: UUID) async throws -> Message
    func messageEvents(conversationID: UUID) async throws -> AsyncStream<Void>
    func conversationEvents() async throws -> AsyncStream<ConversationEvent>
    func markConversationRead(conversationID: UUID) async throws
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

    func messageEvents(conversationID: UUID) async throws -> AsyncStream<Void> {
        let channel = client.channel("conversation:\(conversationID.uuidString)")
        let insertions = channel.postgresChange(
            InsertAction.self,
            table: "messages",
            filter: .eq("conversation_id", value: conversationID)
        )

        try await channel.subscribeWithError()

        return AsyncStream { continuation in
            let observation = Task {
                for await _ in insertions {
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
        let messageInsertions = channel.postgresChange(InsertAction.self, table: "messages")
        let membershipUpdates = channel.postgresChange(
            UpdateAction.self,
            table: "conversation_members",
            filter: .eq("user_id", value: currentUserID)
        )
        let presenceChanges = channel.presenceChange()

        try await channel.subscribeWithError()
        try await channel.track(PresencePayload(userID: currentUserID))

        return AsyncStream { continuation in
            let messagesTask = Task {
                for await _ in messageInsertions {
                    guard !Task.isCancelled else { break }
                    continuation.yield(.contentChanged)
                }
            }
            let membershipsTask = Task {
                for await _ in membershipUpdates {
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
