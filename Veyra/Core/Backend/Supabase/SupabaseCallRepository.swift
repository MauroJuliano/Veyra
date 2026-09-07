import Foundation
@preconcurrency import Supabase

final class SupabaseCallRepository: CallRepository, @unchecked Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func startCall(to participant: VoiceCall) async throws -> VoiceCall {
        guard let participantID = participant.participantID else {
            throw CallRepositoryError.missingParticipant
        }
        let callID: UUID = try await client
            .rpc("start_voice_call", params: ["target_user_id": participantID])
            .execute()
            .value
        return VoiceCall(
            id: callID,
            participantID: participantID,
            participantName: participant.participantName,
            participantAvatarURL: participant.participantAvatarURL,
            direction: .outgoing
        )
    }

    func answerCall(id: UUID, accept: Bool) async throws {
        try await client
            .rpc("answer_voice_call", params: AnswerCallParameters(targetCallID: id, shouldAccept: accept))
            .execute()
    }

    func endCall(id: UUID) async throws {
        try await client
            .rpc("end_voice_call", params: ["target_call_id": id])
            .execute()
    }

    func activeCallEvents() async throws -> AsyncStream<[VoiceCallUpdate]> {
        let channel = client.channel("veyra:voice-calls")
        let changes = channel.postgresChange(AnyAction.self, table: "voice_calls")
        try await channel.subscribeWithError()
        let initialCalls = try await fetchActiveCalls()

        return AsyncStream { continuation in
            continuation.yield(initialCalls)
            let changesTask = Task {
                for await _ in changes {
                    guard !Task.isCancelled else { break }
                    if let calls = try? await self.fetchActiveCalls() {
                        continuation.yield(calls)
                    }
                }
            }

            continuation.onTermination = { [client] _ in
                changesTask.cancel()
                Task { await client.removeChannel(channel) }
            }
        }
    }

    private func fetchActiveCalls() async throws -> [VoiceCallUpdate] {
        let currentUserID = try await client.auth.session.user.id
        let rows: [ActiveVoiceCallRow] = try await client
            .rpc("list_my_active_voice_calls")
            .execute()
            .value

        var updates: [VoiceCallUpdate] = []
        for row in rows {
            let avatarURL: URL?
            if let path = row.peerAvatarPath, !path.isEmpty {
                avatarURL = try? await client.storage.from("avatars").createSignedURL(path: path, expiresIn: 3_600)
            } else {
                avatarURL = nil
            }
            let direction: VoiceCallDirection = row.callerID == currentUserID ? .outgoing : .incoming
            updates.append(VoiceCallUpdate(
                call: VoiceCall(
                    id: row.callID,
                    participantID: row.peerID,
                    participantName: row.peerName,
                    participantAvatarURL: avatarURL,
                    direction: direction,
                    createdAt: row.createdAt
                ),
                state: row.callStatus == "accepted" ? .connected : (direction == .incoming ? .ringing : .calling),
                answeredAt: row.answeredAt
            ))
        }
        return updates
    }
}

private struct AnswerCallParameters: Encodable {
    let targetCallID: UUID
    let shouldAccept: Bool

    enum CodingKeys: String, CodingKey {
        case targetCallID = "target_call_id"
        case shouldAccept = "should_accept"
    }
}

private struct ActiveVoiceCallRow: Decodable {
    let callID: UUID
    let callerID: UUID
    let calleeID: UUID
    let peerID: UUID
    let peerName: String
    let peerAvatarPath: String?
    let callStatus: String
    let createdAt: Date
    let answeredAt: Date?

    enum CodingKeys: String, CodingKey {
        case callID = "call_id"
        case callerID = "caller_id"
        case calleeID = "callee_id"
        case peerID = "peer_id"
        case peerName = "peer_name"
        case peerAvatarPath = "peer_avatar_path"
        case callStatus = "call_status"
        case createdAt = "created_at"
        case answeredAt = "answered_at"
    }
}
