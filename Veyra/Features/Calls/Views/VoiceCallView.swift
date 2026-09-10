import SwiftUI

struct VoiceCallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coordinator: VoiceCallCoordinator

    init(call: VoiceCall, repository: (any CallRepository)? = nil) {
        let audioEngine = repository.map(WebRTCVoiceCallEngine.init(repository:))
        _coordinator = State(initialValue: VoiceCallCoordinator(
            call: call,
            repository: repository,
            audioEngine: audioEngine
        ))
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                Spacer()
                participant
                Spacer()
                controls
            }
            .padding(.horizontal, VeyraSpacing.lg)
            .padding(.vertical, VeyraSpacing.lg)
        }
        .task { await coordinator.start() }
        .onChange(of: coordinator.state) { _, state in
            if state == .ended {
                dismiss()
            }
        }
        .onDisappear { coordinator.abandonIfNeeded() }
        .interactiveDismissDisabled()
    }

    private var background: some View {
        ZStack {
            VeyraColor.background
            RadialGradient(
                colors: [VeyraColor.accent.opacity(0.38), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 480
            )
            LinearGradient(
                colors: [.clear, VeyraColor.background.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button(action: endCall) {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Close call")

            Spacer()
            Text("Veyra voice call")
                .font(VeyraTypography.bodyEmphasized)
                .foregroundStyle(VeyraColor.textSecondary)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .foregroundStyle(VeyraColor.textPrimary)
    }

    private var participant: some View {
        VStack(spacing: VeyraSpacing.lg) {
            VeyraAvatar(
                name: coordinator.call.participantName,
                imageURL: coordinator.call.participantAvatarURL,
                size: .xLarge
            )
            .scaleEffect(1.3)
            .overlay {
                Circle().stroke(VeyraColor.accent.opacity(0.75), lineWidth: 2)
                    .scaleEffect(1.3)
            }
            .shadow(color: VeyraColor.accent.opacity(0.4), radius: 34)
            .padding(.bottom, VeyraSpacing.md)

            Text(coordinator.call.participantName)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(VeyraColor.textPrimary)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(status(at: context.date))
                    .font(VeyraTypography.body)
                    .foregroundStyle(VeyraColor.textSecondary)
                    .contentTransition(.numericText())
            }

            if let errorMessage = coordinator.errorMessage {
                Text(errorMessage)
                    .font(VeyraTypography.caption)
                    .foregroundStyle(VeyraColor.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VeyraSpacing.xl)
            }
        }
        .multilineTextAlignment(.center)
    }

    private var controls: some View {
        Group {
            if coordinator.state == .ringing {
                incomingControls
            } else {
                activeControls
            }
        }
    }

    private var activeControls: some View {
        HStack(spacing: VeyraSpacing.xl) {
            controlButton(
                title: "Mute",
                systemImage: coordinator.isMuted ? "mic.slash.fill" : "mic.fill",
                isSelected: coordinator.isMuted,
                action: coordinator.toggleMute
            )

            Button(action: endCall) {
                Image(systemName: "phone.down.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(VeyraColor.danger, in: Circle())
                    .shadow(color: VeyraColor.danger.opacity(0.35), radius: 16, y: 8)
            }
            .accessibilityLabel("End call")

            controlButton(
                title: "Speaker",
                systemImage: coordinator.isSpeakerEnabled ? "speaker.wave.3.fill" : "speaker.wave.2.fill",
                isSelected: coordinator.isSpeakerEnabled,
                action: coordinator.toggleSpeaker
            )
        }
        .padding(.vertical, VeyraSpacing.xl)
        .frame(maxWidth: .infinity)
        .background { GlassBackground(cornerRadius: 32, tintOpacity: 0.1, glowOpacity: 0.12) }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private var incomingControls: some View {
        HStack(spacing: 72) {
            callActionButton(
                title: "Decline",
                systemImage: "phone.down.fill",
                color: VeyraColor.danger
            ) {
                Task { await coordinator.decline() }
            }
            callActionButton(
                title: "Accept",
                systemImage: "phone.fill",
                color: VeyraColor.success
            ) {
                Task { await coordinator.answer() }
            }
        }
        .padding(.vertical, VeyraSpacing.xl)
        .frame(maxWidth: .infinity)
        .background { GlassBackground(cornerRadius: 32, tintOpacity: 0.1, glowOpacity: 0.12) }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func callActionButton(
        title: LocalizedStringKey,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: VeyraSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(color, in: Circle())
                Text(title)
                    .font(VeyraTypography.caption)
                    .foregroundStyle(VeyraColor.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func controlButton(
        title: LocalizedStringKey,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: VeyraSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 58, height: 58)
                    .background(isSelected ? VeyraColor.textPrimary : VeyraColor.surfaceElevated, in: Circle())
                    .foregroundStyle(isSelected ? VeyraColor.background : VeyraColor.textPrimary)
                Text(title)
                    .font(VeyraTypography.caption)
                    .foregroundStyle(VeyraColor.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func status(at date: Date) -> String {
        switch coordinator.state {
        case .idle: AppLocalization.string("Preparing call…")
        case .ringing: AppLocalization.string("Incoming call…")
        case .calling: AppLocalization.string("Calling…")
        case .connecting: AppLocalization.string("Connecting…")
        case .connected:
            coordinator.connectedAt.map { duration(from: $0, to: date) } ?? AppLocalization.string("Connected")
        case .ended: AppLocalization.string("Call ended")
        case .failed: AppLocalization.string("Call failed")
        }
    }

    private func duration(from start: Date, to end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func endCall() {
        coordinator.end()
        dismiss()
    }
}

#Preview("Outgoing call") {
    VoiceCallView(
        call: VoiceCall(
            participantID: UUID(),
            participantName: "Martha Nielsen",
            participantAvatarURL: nil
        )
    )
    .preferredColorScheme(.dark)
}
