import Foundation
@preconcurrency import Supabase

final class SupabaseChatRepository: RemoteChatRepository, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    // MARK: - Device registration

    func registerPushToken(_ token: String) async throws {
        try await client.rpc("register_push_token", params: ["device_token": token]).execute()
    }

    func unregisterPushToken(_ token: String) async throws {
        try await client.rpc("unregister_push_token", params: ["device_token": token]).execute()
    }

    // MARK: - Conversations

    func fetchConversations() async throws -> [Conversation] {
        let rows: [ConversationRow] = try await client
            .rpc("list_my_conversations")
            .execute()
            .value
        var conversations: [Conversation] = []
        for row in rows {
            conversations.append(row.conversation(avatarURL: try await signedAvatarURL(path: row.avatarPath)))
        }
        return conversations
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
                isOnline: contact.isOnline,
                participantAvatarURL: contact.avatarURL
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

    // MARK: - Messages

    func fetchMessages(conversationID: UUID, before: Date? = nil, limit: Int = 50) async throws -> [Message] {
        let currentUserID = try await client.auth.session.user.id
        let parameters = MessagePageParameters(
            conversationID: conversationID,
            beforeMessageDate: before,
            pageSize: min(max(limit, 1), 100)
        )
        let rows: [MessageRow] = try await client
            .rpc("list_conversation_messages", params: parameters)
            .execute()
            .value
        var messages: [Message] = []
        for row in rows {
            let signedURL: URL?
            if let imagePath = row.imagePath {
                signedURL = try await client.storage.from("chat-media").createSignedURL(path: imagePath, expiresIn: 3_600)
            } else {
                signedURL = nil
            }
            let audioURL: URL?
            if let audioPath = row.audioPath {
                audioURL = try await client.storage.from("chat-media").createSignedURL(path: audioPath, expiresIn: 3_600)
            } else {
                audioURL = nil
            }
            messages.append(row.message(currentUserID: currentUserID, imageURL: signedURL, audioURL: audioURL))
        }
        return messages
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

    func sendMessage(_ text: String, conversationID: UUID, replyingTo messageID: UUID? = nil, clientMessageID: UUID? = nil) async throws -> Message {
        guard try await canSendMessages(conversationID: conversationID) else {
            throw ChatRepositoryError.messagingBlocked
        }
        let currentUserID = try await client.auth.session.user.id
        let identifier = clientMessageID ?? UUID()
        let payload = NewMessageRow(id: identifier, conversationID: conversationID, senderID: currentUserID, body: text, replyToMessageID: messageID)
        let row: MessageRow
        do {
            row = try await client
                .from("messages")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
        } catch {
            // A retry can arrive after the insert succeeded but its response
            // was lost. Fetching the same client-generated ID makes sending
            // idempotent instead of creating a duplicate message.
            row = try await client
                .from("messages")
                .select()
                .eq("id", value: identifier)
                .single()
                .execute()
                .value
        }
        return row.message(currentUserID: currentUserID, imageURL: nil, audioURL: nil)
    }

    func toggleReaction(_ emoji: String, messageID: UUID) async throws {
        try await client.rpc("toggle_message_reaction", params: [
            "target_message_id": messageID.uuidString,
            "target_emoji": emoji
        ]).execute()
    }

    func sendImage(_ data: Data, conversationID: UUID) async throws -> Message {
        guard try await canSendMessages(conversationID: conversationID) else {
            throw ChatRepositoryError.messagingBlocked
        }
        let currentUserID = try await client.auth.session.user.id
        let path = [
            currentUserID.uuidString.lowercased(),
            conversationID.uuidString.lowercased(),
            "\(UUID().uuidString.lowercased()).jpg"
        ].joined(separator: "/")
        let bucket = client.storage.from("chat-media")
        try await bucket.upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
        let imageURL = try await bucket.createSignedURL(path: path, expiresIn: 3_600)
        let payload = NewMessageRow(conversationID: conversationID, senderID: currentUserID, body: "Photo", imagePath: path)
        let row: MessageRow = try await client.from("messages").insert(payload).select().single().execute().value
        return row.message(currentUserID: currentUserID, imageURL: imageURL, audioURL: nil)
    }

    func sendAudio(_ data: Data, duration: TimeInterval, conversationID: UUID) async throws -> Message {
        guard try await canSendMessages(conversationID: conversationID) else {
            throw ChatRepositoryError.messagingBlocked
        }
        let currentUserID = try await client.auth.session.user.id
        let path = [currentUserID.uuidString.lowercased(), conversationID.uuidString.lowercased(), "\(UUID().uuidString.lowercased()).m4a"].joined(separator: "/")
        let bucket = client.storage.from("chat-media")
        try await bucket.upload(path, data: data, options: FileOptions(contentType: "audio/mp4"))
        let audioURL = try await bucket.createSignedURL(path: path, expiresIn: 3_600)
        let payload = NewMessageRow(conversationID: conversationID, senderID: currentUserID, body: "Audio", audioPath: path, audioDurationMilliseconds: Int(duration * 1_000))
        let row: MessageRow = try await client.from("messages").insert(payload).select().single().execute().value
        return row.message(currentUserID: currentUserID, imageURL: nil, audioURL: audioURL)
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

    // MARK: - Contacts and discovery

    func fetchContacts() async throws -> [Contact] {
        let rows: [ContactRow] = try await client
            .rpc("list_my_contacts")
            .execute()
            .value
        var contacts: [Contact] = []
        for row in rows {
            contacts.append(row.contact(avatarURL: try await signedAvatarURL(path: row.avatarPath)))
        }
        return contacts
    }

    func searchPeople(query: String) async throws -> [User] {
        let rows: [PeopleSearchRow] = try await client
            .rpc("search_people", params: PeopleSearchParameters(searchQuery: query, resultLimit: 20))
            .execute()
            .value
        var users: [User] = []
        for row in rows {
            users.append(row.user(avatarURL: try? await signedAvatarURL(path: row.avatarPath)))
        }
        return users
    }

    // MARK: - Profiles and safety

    func fetchMyProfile() async throws -> UserProfile {
        let session = try await client.auth.session
        let userID = session.user.id
        let row: ProfileRow = try await client.from("profiles").select().eq("id", value: userID).single().execute().value
        return row.profile(email: session.user.email ?? "", avatarURL: try await signedAvatarURL(path: row.avatarPath))
    }

    func fetchPublicProfile(userID: UUID) async throws -> User {
        let row: PublicProfileRow = try await client
            .from("profiles")
            .select("id, display_name, username, avatar_url, bio")
            .eq("id", value: userID)
            .single()
            .execute()
            .value
        return row.user(avatarURL: try await signedAvatarURL(path: row.avatarPath))
    }

    func fetchBlockRelationship(userID: UUID) async throws -> BlockRelationship {
        let rows: [BlockRelationshipRow] = try await client
            .rpc("get_block_relationship", params: ["target_user_id": userID.uuidString])
            .execute()
            .value
        guard let row = rows.first else { return BlockRelationship() }
        return BlockRelationship(isBlockedByMe: row.isBlockedByMe, isBlockedByThem: row.isBlockedByThem)
    }

    func setUserBlocked(userID: UUID, isBlocked: Bool) async throws {
        try await client.rpc(
            "set_user_block",
            params: UserBlockParameters(userID: userID, shouldBlock: isBlocked)
        ).execute()
    }

    func fetchBlockedUsers() async throws -> [User] {
        let rows: [PeopleSearchRow] = try await client.rpc("list_blocked_users").execute().value
        var users: [User] = []
        for row in rows {
            users.append(row.user(avatarURL: try? await signedAvatarURL(path: row.avatarPath)))
        }
        return users
    }

    func canSendMessages(conversationID: UUID) async throws -> Bool {
        try await client
            .rpc("can_send_to_conversation", params: ["target_conversation_id": conversationID.uuidString])
            .execute()
            .value
    }

    func reportUser(userID: UUID, reason: String, details: String) async throws {
        try await client.rpc(
            "report_user",
            params: UserReportParameters(userID: userID, reason: reason, details: details)
        ).execute()
    }

    func updateMyProfile(displayName: String, username: String, bio: String, email: String) async throws -> UserProfile {
        let currentEmail = try await client.auth.session.user.email ?? ""
        if email.caseInsensitiveCompare(currentEmail) != .orderedSame {
            _ = try await client.auth.update(user: UserAttributes(email: email))
        }
        try await client.rpc("update_my_profile", params: ProfileUpdateParameters(
            displayName: displayName,
            username: username,
            bio: bio
        )).execute()
        var profile = try await fetchMyProfile()
        if profile.email.isEmpty || email.caseInsensitiveCompare(currentEmail) != .orderedSame {
            profile.email = email
        }
        return profile
    }

    func updateMyAvatar(_ data: Data) async throws -> UserProfile {
        let userID = try await client.auth.session.user.id
        let path = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        try await client.storage.from("avatars").upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        try await client.from("profiles").update(AvatarPathRow(avatarPath: path)).eq("id", value: userID).execute()
        return try await fetchMyProfile()
    }

    // MARK: - Message realtime

    func messageEvents(conversationID: UUID, participantID: UUID?) async throws -> AsyncStream<MessageEvent> {
        let currentUserID = try await client.auth.session.user.id
        let messagesChannel = client.channel("messages:\(conversationID.uuidString)")
        // Supabase does not reliably apply column filters to DELETE payloads.
        // RLS still limits events to the signed-in user's conversations, and
        // the timeline refetch below keeps this conversation consistent.
        let changes = messagesChannel.postgresChange(AnyAction.self, table: "messages")
        let reactionChanges = messagesChannel.postgresChange(AnyAction.self, table: "message_reactions")
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
            let reactionsTask = Task {
                for await _ in reactionChanges {
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
                reactionsTask.cancel()
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

    // MARK: - Presence and conversation realtime

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
        let callChanges = channel.postgresChange(AnyAction.self, table: "voice_calls")

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
            let callsTask = Task {
                for await _ in callChanges {
                    guard !Task.isCancelled else { break }
                    continuation.yield(.contentChanged)
                }
            }

            continuation.onTermination = { [client] _ in
                messagesTask.cancel()
                membershipsTask.cancel()
                presenceTask.cancel()
                callsTask.cancel()
                Task { await client.removeChannel(channel) }
            }
        }
    }

    // MARK: - Realtime helpers

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

    private func signedAvatarURL(path: String?) async throws -> URL? {
        guard let path else { return nil }
        return try await client.storage.from("avatars").createSignedURL(path: path, expiresIn: 3_600)
    }
}

enum ChatRepositoryError: LocalizedError {
    case conversationNotFound
    case messagingBlocked

    var errorDescription: String? {
        switch self {
        case .conversationNotFound: String(localized: "The conversation could not be loaded.")
        case .messagingBlocked: String(localized: "Messages are unavailable while either user is blocked.")
        }
    }
}

struct BlockRelationship: Equatable, Sendable {
    var isBlockedByMe = false
    var isBlockedByThem = false
    var preventsMessaging: Bool { isBlockedByMe || isBlockedByThem }
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
    let avatarPath: String?

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
        case avatarPath = "avatar_path"
    }

    func conversation(avatarURL: URL?) -> Conversation {
        let preview = lastMessage.hasPrefix("[sticker]")
            ? "Sticker \(lastMessage.dropFirst("[sticker]".count))"
            : lastMessage
        return Conversation(id: conversationID, participantID: participantID, participantName: participantName, lastMessage: preview, updatedAt: updatedAt, unreadCount: unreadCount, isOnline: isOnline, lastSeenAt: lastSeenAt, lastMessageIsMine: lastMessageIsMine, lastMessageIsRead: lastMessageIsRead, participantAvatarURL: avatarURL)
    }
}

private struct ContactRow: Decodable {
    let contactID: UUID
    let displayName: String
    let conversationID: UUID?
    let avatarPath: String?
    let bio: String?

    enum CodingKeys: String, CodingKey {
        case contactID = "contact_id"
        case displayName = "display_name"
        case conversationID = "conversation_id"
        case avatarPath = "avatar_path"
        case bio
    }

    func contact(avatarURL: URL?) -> Contact {
        Contact(id: contactID, name: displayName, conversationID: conversationID, bio: bio, avatarURL: avatarURL)
    }
}

private struct PeopleSearchRow: Decodable {
    let userID: UUID
    let displayName: String
    let username: String?
    let avatarPath: String?
    let bio: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case username
        case avatarPath = "avatar_path"
        case bio
    }

    func user(avatarURL: URL?) -> User {
        User(id: userID, participantID: userID, participantName: displayName, userName: username.map { "@\($0)" } ?? "", bio: bio, participantAvatarURL: avatarURL)
    }
}

private struct PeopleSearchParameters: Encodable {
    let searchQuery: String
    let resultLimit: Int

    enum CodingKeys: String, CodingKey {
        case searchQuery = "search_query"
        case resultLimit = "result_limit"
    }
}

private struct BlockRelationshipRow: Decodable {
    let isBlockedByMe: Bool
    let isBlockedByThem: Bool

    enum CodingKeys: String, CodingKey {
        case isBlockedByMe = "is_blocked_by_me"
        case isBlockedByThem = "is_blocked_by_them"
    }
}

private struct UserBlockParameters: Encodable {
    let userID: UUID
    let shouldBlock: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "target_user_id"
        case shouldBlock = "should_block"
    }
}

private struct UserReportParameters: Encodable {
    let userID: UUID
    let reason: String
    let details: String

    enum CodingKeys: String, CodingKey {
        case userID = "target_user_id"
        case reason = "report_reason"
        case details = "report_details"
    }
}

private struct ProfileRow: Decodable {
    let displayName: String
    let username: String?
    let avatarPath: String?
    let bio: String?
    enum CodingKeys: String, CodingKey { case displayName = "display_name"; case username; case avatarPath = "avatar_url"; case bio }
    func profile(email: String, avatarURL: URL?) -> UserProfile {
        UserProfile(displayName: displayName, username: username ?? "veyrauser", avatarURL: avatarURL, bio: bio ?? "", email: email)
    }
}

private struct PublicProfileRow: Decodable {
    let id: UUID
    let displayName: String
    let username: String?
    let avatarPath: String?
    let bio: String?

    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"
        case avatarPath = "avatar_url"
    }

    func user(avatarURL: URL?) -> User {
        User(
            id: id,
            participantID: id,
            participantName: displayName,
            userName: username.map { "@\($0)" } ?? "",
            bio: bio,
            participantAvatarURL: avatarURL
        )
    }
}

private struct ProfileUpdateParameters: Encodable {
    let displayName: String
    let username: String
    let bio: String

    enum CodingKeys: String, CodingKey {
        case displayName = "new_display_name"
        case username = "new_username"
        case bio = "new_bio"
    }
}

private struct AvatarPathRow: Encodable {
    let avatarPath: String
    enum CodingKeys: String, CodingKey { case avatarPath = "avatar_url" }
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
    let imagePath: String?
    let audioPath: String?
    let audioDurationMilliseconds: Int?
    let replyToMessageID: UUID?
    let replyBody: String?
    let replySenderID: UUID?
    let reactions: [ReactionRow]?

    enum CodingKeys: String, CodingKey {
        case id, body
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case createdAt = "created_at"
        case isRead = "is_read"
        case imagePath = "image_path"
        case audioPath = "audio_path"
        case audioDurationMilliseconds = "audio_duration_ms"
        case replyToMessageID = "reply_to_message_id"
        case replyBody = "reply_body"
        case replySenderID = "reply_sender_id"
        case reactions
    }

    func message(currentUserID: UUID, imageURL: URL?, audioURL: URL?) -> Message {
        let stickerPrefix = "[sticker]"
        let isSticker = body.hasPrefix(stickerPrefix)
        return Message(
            id: id,
            text: isSticker ? String(body.dropFirst(stickerPrefix.count)) : body,
            sentAt: createdAt,
            direction: senderID == currentUserID ? .outgoing : .incoming,
            receipt: isRead == true ? .read : .sent,
            imageURL: imageURL,
            audioURL: audioURL,
            audioDuration: audioDurationMilliseconds.map { TimeInterval($0) / 1_000 },
            isSticker: isSticker,
            replyPreview: replyToMessageID.map {
                Message.ReplyPreview(messageID: $0, text: replyBody ?? String(localized: "Message unavailable"), isOwnMessage: replySenderID == currentUserID)
            },
            reactions: (reactions ?? []).map {
                Message.Reaction(emoji: $0.emoji, count: $0.count, isSelectedByCurrentUser: $0.selected)
            }
        )
    }
}

private struct MessagePageParameters: Encodable {
    let conversationID: UUID
    let beforeMessageDate: Date?
    let pageSize: Int

    enum CodingKeys: String, CodingKey {
        case conversationID = "target_conversation_id"
        case beforeMessageDate = "before_message_date"
        case pageSize = "page_size"
    }
}

private struct ReactionRow: Decodable {
    let emoji: String
    let count: Int
    let selected: Bool
}

private struct NewMessageRow: Encodable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let body: String
    let imagePath: String?
    let audioPath: String?
    let audioDurationMilliseconds: Int?
    let replyToMessageID: UUID?

    init(id: UUID = UUID(), conversationID: UUID, senderID: UUID, body: String, imagePath: String? = nil, audioPath: String? = nil, audioDurationMilliseconds: Int? = nil, replyToMessageID: UUID? = nil) {
        self.id = id
        self.conversationID = conversationID
        self.senderID = senderID
        self.body = body
        self.imagePath = imagePath
        self.audioPath = audioPath
        self.audioDurationMilliseconds = audioDurationMilliseconds
        self.replyToMessageID = replyToMessageID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case body
        case imagePath = "image_path"
        case audioPath = "audio_path"
        case audioDurationMilliseconds = "audio_duration_ms"
        case replyToMessageID = "reply_to_message_id"
    }
}
