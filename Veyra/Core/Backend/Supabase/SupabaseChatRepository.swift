import Foundation
@preconcurrency import Supabase

protocol RemoteChatRepository: Sendable {
    func fetchConversations() async throws -> [Conversation]
    func startConversation(withEmail email: String) async throws -> Conversation
    func startConversation(with contact: Contact) async throws -> Conversation
    func fetchMessages(conversationID: UUID) async throws -> [Message]
    func sendMessage(_ text: String, conversationID: UUID) async throws -> Message
    func messageEvents(conversationID: UUID, participantID: UUID?) async throws -> AsyncStream<MessageEvent>
    func setTyping(_ isTyping: Bool, conversationID: UUID) async throws
    func conversationEvents() async throws -> AsyncStream<ConversationEvent>
    func markConversationRead(conversationID: UUID) async throws
    func deleteMessage(id: UUID) async throws
    func deleteConversation(id: UUID) async throws
    func fetchContacts() async throws -> [Contact]
    func maintainPresence() async
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
            .rpc("list_conversation_messages", params: ["target_conversation_id": conversationID])
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

    func messageEvents(conversationID: UUID, participantID: UUID?) async throws -> AsyncStream<MessageEvent> {
        let currentUserID = try await client.auth.session.user.id
        let messagesChannel = client.channel("messages:\(conversationID.uuidString)")
        // Supabase does not reliably apply column filters to DELETE payloads.
        // RLS still limits events to the signed-in user's conversations, and
        // the timeline refetch below keeps this conversation consistent.
        let changes = messagesChannel.postgresChange(AnyAction.self, table: "messages")
        let typingChanges = messagesChannel.postgresChange(
            AnyAction.self,
            table: "typing_status",
            filter: .eq("conversation_id", value: conversationID)
        )
        let presenceChanges = messagesChannel.postgresChange(AnyAction.self, table: "user_presence")
        let readChanges = messagesChannel.postgresChange(
            AnyAction.self,
            table: "conversation_members",
            filter: .eq("conversation_id", value: conversationID)
        )

        // Message synchronization is essential and must not depend on the
        // optional typing channel being authorized or available.
        try await messagesChannel.subscribeWithError()

        return AsyncStream { continuation in
            let messagesTask = Task {
                for await _ in changes {
                    guard !Task.isCancelled else { break }
                    continuation.yield(.contentChanged)
                }
            }
            let typingTask = Task {
                for await _ in typingChanges {
                    guard !Task.isCancelled else { break }
                    let isTyping = (try? await self.fetchParticipantTyping(
                        conversationID: conversationID,
                        currentUserID: currentUserID
                    )) ?? false
                    continuation.yield(.typingChanged(isTyping))
                }
            }
            let presenceTask = Task {
                for await _ in presenceChanges {
                    guard !Task.isCancelled, let participantID else { continue }
                    if let presence = try? await self.fetchPresence(userID: participantID) {
                        continuation.yield(.presenceChanged(
                            isActive: presence.isActive,
                            lastSeenAt: presence.lastSeenAt
                        ))
                    }
                }
            }
            let readTask = Task {
                for await _ in readChanges {
                    guard !Task.isCancelled else { break }
                    continuation.yield(.readReceiptChanged)
                }
            }

            continuation.onTermination = { [client] _ in
                messagesTask.cancel()
                typingTask.cancel()
                presenceTask.cancel()
                readTask.cancel()
                Task {
                    await client.removeChannel(messagesChannel)
                }
            }
        }
    }

    func setTyping(_ isTyping: Bool, conversationID: UUID) async throws {
        let currentUserID = try await client.auth.session.user.id
        try await client
            .from("typing_status")
            .upsert(TypingStatusRow(
                conversationID: conversationID,
                userID: currentUserID,
                isTyping: isTyping,
                updatedAt: .now
            ))
            .execute()
    }

    func maintainPresence() async {
        while !Task.isCancelled {
            do {
                let currentUserID = try await client.auth.session.user.id
                try await client
                    .from("user_presence")
                    .upsert(UserPresenceRow(userID: currentUserID, lastSeenAt: .now))
                    .execute()
            } catch is CancellationError {
                return
            } catch {
                // Presence is best effort and must never affect chat usage.
            }

            try? await Task.sleep(for: .seconds(20))
        }
    }

    func conversationEvents() async throws -> AsyncStream<ConversationEvent> {
        let channel = client.channel("veyra:conversation-events")
        let messageChanges = channel.postgresChange(AnyAction.self, table: "messages")
        let membershipChanges = channel.postgresChange(AnyAction.self, table: "conversation_members")
        let presenceChanges = channel.postgresChange(AnyAction.self, table: "user_presence")

        try await channel.subscribeWithError()

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
                for await _ in presenceChanges {
                    guard !Task.isCancelled else { break }
                    continuation.yield(.contentChanged)
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

    private func fetchParticipantTyping(conversationID: UUID, currentUserID: UUID) async throws -> Bool {
        let rows: [TypingStatusRow] = try await client
            .from("typing_status")
            .select()
            .eq("conversation_id", value: conversationID)
            .neq("user_id", value: currentUserID)
            .execute()
            .value
        return rows.contains { $0.isTyping && $0.updatedAt > Date().addingTimeInterval(-3) }
    }

    private func fetchPresence(userID: UUID) async throws -> ParticipantPresence {
        let rows: [UserPresenceRow] = try await client
            .from("user_presence")
            .select()
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else {
            return ParticipantPresence(isActive: false, lastSeenAt: nil)
        }
        return ParticipantPresence(
            isActive: row.lastSeenAt > Date().addingTimeInterval(-60),
            lastSeenAt: row.lastSeenAt
        )
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
    let isOnline: Bool
    let lastSeenAt: Date?
    let lastMessageIsMine: Bool
    let lastMessageIsRead: Bool

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case participantID = "participant_id"
        case participantName = "participant_name"
        case lastMessage = "last_message"
        case updatedAt = "updated_at"
        case unreadCount = "unread_count"
        case isOnline = "is_online"
        case lastSeenAt = "last_seen_at"
        case lastMessageIsMine = "last_message_is_mine"
        case lastMessageIsRead = "last_message_is_read"
    }

    var conversation: Conversation {
        Conversation(id: conversationID, participantID: participantID, participantName: participantName, lastMessage: lastMessage, updatedAt: updatedAt, unreadCount: unreadCount, isOnline: isOnline, lastSeenAt: lastSeenAt, lastMessageIsMine: lastMessageIsMine, lastMessageIsRead: lastMessageIsRead)
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

private struct TypingStatusRow: Codable {
    let conversationID: UUID
    let userID: UUID
    let isTyping: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case conversationID = "conversation_id"
        case userID = "user_id"
        case isTyping = "is_typing"
        case updatedAt = "updated_at"
    }
}

private struct UserPresenceRow: Codable {
    let userID: UUID
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case lastSeenAt = "last_seen_at"
    }
}

private struct ParticipantPresence {
    let isActive: Bool
    let lastSeenAt: Date?
}

private struct MessageRow: Decodable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let body: String
    let createdAt: Date
    let isRead: Bool?

    enum CodingKeys: String, CodingKey {
        case id, body
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case createdAt = "created_at"
        case isRead = "is_read"
    }

    func message(currentUserID: UUID) -> Message {
        Message(
            id: id,
            text: body,
            sentAt: createdAt,
            direction: senderID == currentUserID ? .outgoing : .incoming,
            receipt: isRead == true ? .read : .sent
        )
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
