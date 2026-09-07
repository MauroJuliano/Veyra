import AVFoundation
import Foundation
@preconcurrency import WebRTC

@MainActor
final class WebRTCVoiceCallEngine: NSObject, VoiceCallAudioEngine {
    private let repository: any CallRepository
    private var factory: RTCPeerConnectionFactory?
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var signalsTask: Task<Void, Never>?
    private var processedSignalIDs = Set<Int64>()
    private var pendingCandidates: [RTCIceCandidate] = []
    private var hasRemoteDescription = false
    private var callID: UUID?

    init(repository: any CallRepository) {
        self.repository = repository
        super.init()
    }

    func startOutgoing(callID: UUID) async throws {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw VoiceCallAudioError.microphonePermissionDenied
        }
        try await configure(callID: callID)
        observeSignals(callID: callID)
        let offer = try await createOffer()
        try await setLocalDescription(offer)
        try await repository.sendSignal(.offer(offer.sdp), callID: callID)
    }

    func startIncoming(callID: UUID) async throws {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw VoiceCallAudioError.microphonePermissionDenied
        }
        try await configure(callID: callID)
        observeSignals(callID: callID)
    }

    func setMuted(_ isMuted: Bool) {
        localAudioTrack?.isEnabled = !isMuted
    }

    func setSpeakerEnabled(_ isEnabled: Bool) throws {
        try AVAudioSession.sharedInstance().overrideOutputAudioPort(isEnabled ? .speaker : .none)
    }

    func stop() {
        signalsTask?.cancel()
        signalsTask = nil
        peerConnection?.close()
        peerConnection = nil
        localAudioTrack = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configure(callID: UUID) async throws {
        guard peerConnection == nil else { return }
        self.callID = callID

        // WebRTC objects have signaling-thread affinity. The factory and the
        // peer connection must be created and used from this same actor.
        RTCInitializeSSL()
        let factory = RTCPeerConnectionFactory()
        self.factory = factory

        try await Task.detached(priority: .userInitiated) {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try audioSession.setActive(true)
        }.value

        let configuration = RTCConfiguration()
        configuration.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"])
        ]
        configuration.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement": "true"])
        guard let connection = factory.peerConnection(with: configuration, constraints: constraints, delegate: self) else {
            throw VoiceCallAudioError.peerConnectionUnavailable
        }
        peerConnection = connection

        let source = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        let track = factory.audioTrack(with: source, trackId: "veyra-audio")
        localAudioTrack = track
        connection.add(track, streamIds: ["veyra-stream"])
    }

    private func observeSignals(callID: UUID) {
        signalsTask?.cancel()
        signalsTask = Task { [weak self] in
            guard let self else { return }
            do {
                let events = try await repository.signalEvents(callID: callID)
                for await envelopes in events {
                    guard !Task.isCancelled else { return }
                    for envelope in envelopes where processedSignalIDs.insert(envelope.id).inserted {
                        try await handle(envelope.signal)
                    }
                }
            } catch {
                return
            }
        }
    }

    private func handle(_ signal: CallSignal) async throws {
        switch signal {
        case let .offer(sdp):
            try await setRemoteDescription(RTCSessionDescription(type: .offer, sdp: sdp))
            let answer = try await createAnswer()
            try await setLocalDescription(answer)
            guard let callID else { return }
            try await repository.sendSignal(.answer(answer.sdp), callID: callID)
        case let .answer(sdp):
            try await setRemoteDescription(RTCSessionDescription(type: .answer, sdp: sdp))
        case let .ice(candidate, sdpMid, sdpMLineIndex):
            let ice = RTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
            if hasRemoteDescription { try await add(ice) }
            else { pendingCandidates.append(ice) }
        }
    }

    private func createOffer() async throws -> RTCSessionDescription {
        guard let peerConnection else { throw VoiceCallAudioError.peerConnectionUnavailable }
        return try await Self.createOffer(
            on: WebRTCPeerConnectionBox(peerConnection),
            constraints: mediaConstraints
        )
    }

    private func createAnswer() async throws -> RTCSessionDescription {
        guard let peerConnection else { throw VoiceCallAudioError.peerConnectionUnavailable }
        return try await Self.createAnswer(
            on: WebRTCPeerConnectionBox(peerConnection),
            constraints: mediaConstraints
        )
    }

    private var mediaConstraints: RTCMediaConstraints {
        RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "false"], optionalConstraints: nil)
    }

    nonisolated private static func createOffer(
        on connection: WebRTCPeerConnectionBox,
        constraints: RTCMediaConstraints
    ) async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RTCSessionDescription, any Error>) in
            connection.value.offer(for: constraints) { description, error in
                if let error { continuation.resume(throwing: error) }
                else if let description { continuation.resume(returning: description) }
                else { continuation.resume(throwing: VoiceCallAudioError.missingSessionDescription) }
            }
        }
    }

    nonisolated private static func createAnswer(
        on connection: WebRTCPeerConnectionBox,
        constraints: RTCMediaConstraints
    ) async throws -> RTCSessionDescription {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<RTCSessionDescription, any Error>) in
            connection.value.answer(for: constraints) { description, error in
                if let error { continuation.resume(throwing: error) }
                else if let description { continuation.resume(returning: description) }
                else { continuation.resume(throwing: VoiceCallAudioError.missingSessionDescription) }
            }
        }
    }

    private func setLocalDescription(_ description: RTCSessionDescription) async throws {
        guard let peerConnection else { throw VoiceCallAudioError.peerConnectionUnavailable }
        try await Self.setLocalDescription(description, on: WebRTCPeerConnectionBox(peerConnection))
    }

    nonisolated private static func setLocalDescription(
        _ description: RTCSessionDescription,
        on connection: WebRTCPeerConnectionBox
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.value.setLocalDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }

    private func setRemoteDescription(_ description: RTCSessionDescription) async throws {
        guard let peerConnection else { throw VoiceCallAudioError.peerConnectionUnavailable }
        try await Self.setRemoteDescription(description, on: WebRTCPeerConnectionBox(peerConnection))
        hasRemoteDescription = true
        for candidate in pendingCandidates { try await add(candidate) }
        pendingCandidates.removeAll()
    }

    nonisolated private static func setRemoteDescription(
        _ description: RTCSessionDescription,
        on connection: WebRTCPeerConnectionBox
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.value.setRemoteDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }

    private func add(_ candidate: RTCIceCandidate) async throws {
        guard let peerConnection else { throw VoiceCallAudioError.peerConnectionUnavailable }
        try await Self.add(candidate, on: WebRTCPeerConnectionBox(peerConnection))
    }

    nonisolated private static func add(
        _ candidate: RTCIceCandidate,
        on connection: WebRTCPeerConnectionBox
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.value.add(candidate) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }
}

private final class WebRTCPeerConnectionBox: @unchecked Sendable {
    let value: RTCPeerConnection

    init(_ value: RTCPeerConnection) {
        self.value = value
    }
}

extension WebRTCVoiceCallEngine: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Task { @MainActor [weak self] in
            guard let self, let callID else { return }
            try? await repository.sendSignal(.ice(candidate: candidate.sdp, sdpMid: candidate.sdpMid, sdpMLineIndex: candidate.sdpMLineIndex), callID: callID)
        }
    }

    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}

enum VoiceCallAudioError: LocalizedError {
    case peerConnectionUnavailable
    case missingSessionDescription
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied: String(localized: "Microphone access is required for voice calls.")
        default: String(localized: "Unable to connect audio for this call.")
        }
    }
}
