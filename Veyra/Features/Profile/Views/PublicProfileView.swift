import SwiftUI

struct PublicProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var user: User
    @State private var isLoading = false
    @State private var errorMessage: String?

    let repository: (any RemoteChatRepository)?
    let isActive: Bool?
    var onMessage: ((User) async -> Void)?

    init(
        user: User,
        repository: (any RemoteChatRepository)?,
        isActive: Bool? = nil,
        onMessage: ((User) async -> Void)? = nil
    ) {
        _user = State(initialValue: user)
        self.repository = repository
        self.isActive = isActive
        self.onMessage = onMessage
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VeyraSpacing.xl) {
                identity
                messageButton
                aboutCard

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .font(VeyraTypography.caption)
                        .foregroundStyle(VeyraColor.danger)
                }
            }
            .padding(.horizontal, VeyraSpacing.lg)
            .padding(.top, VeyraSpacing.lg)
            .padding(.bottom, VeyraSpacing.xl)
        }
        .background(profileBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await loadProfile() }
    }

    private var identity: some View {
        VStack(spacing: VeyraSpacing.sm) {
            VeyraAvatar(
                name: user.participantName,
                imageURL: user.participantAvatarURL,
                size: .xLarge,
                showsOnlineIndicator: isActive == true
            )
            .overlay {
                Circle().stroke(VeyraColor.accent.opacity(0.85), lineWidth: 2)
            }
            .shadow(color: VeyraColor.accent.opacity(0.22), radius: 24)

            Text(user.participantName)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(VeyraColor.textPrimary)

            if !user.userName.isEmpty {
                Text(user.userName)
                    .font(VeyraTypography.body)
                    .foregroundStyle(VeyraColor.textSecondary)
            }

            Text(displayedBio)
                .font(VeyraTypography.body)
                .foregroundStyle(VeyraColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.top, VeyraSpacing.xs)
        }
        .frame(maxWidth: .infinity)
    }

    private var messageButton: some View {
        Button {
            Task {
                if let onMessage {
                    await onMessage(user)
                } else {
                    dismiss()
                }
            }
        } label: {
            Label("Message", systemImage: "message.fill")
                .font(VeyraTypography.bodyEmphasized)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background {
                    LinearGradient(
                        colors: [VeyraColor.accent, VeyraColor.accent.opacity(0.65)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: VeyraColor.accent.opacity(0.22), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.md) {
            Label("About", systemImage: "person")
                .font(VeyraTypography.title)
                .foregroundStyle(VeyraColor.textPrimary)

            if let isActive {
                Label(isActive ? "Active now" : "Offline", systemImage: "circle.fill")
                    .font(VeyraTypography.body)
                    .foregroundStyle(isActive ? VeyraColor.success : VeyraColor.textSecondary)
            }

            Label(displayedBio, systemImage: "quote.bubble")
                .font(VeyraTypography.body)
                .foregroundStyle(VeyraColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VeyraSpacing.lg)
        .background { GlassBackground(cornerRadius: 28, tintOpacity: 0.1, glowOpacity: 0.1) }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var displayedBio: String {
        user.bio.flatMap { $0.isEmpty ? nil : $0 } ?? "No bio yet"
    }

    private var profileBackground: some View {
        LinearGradient(
            colors: [VeyraColor.accentMuted.opacity(0.55), VeyraColor.background, VeyraColor.background],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
        .ignoresSafeArea()
    }

    @MainActor
    private func loadProfile() async {
        guard let repository, let userID = user.participantID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            user = try await repository.fetchPublicProfile(userID: userID)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to refresh this profile."
        }
    }
}

#Preview {
    NavigationStack {
        PublicProfileView(
            user: User(
                participantName: "Martha Nielsen",
                userName: "@martha",
                bio: "Quiet nights, old music, and meaningful conversations.",
                participantAvatarURL: nil
            ),
            repository: nil,
            isActive: true
        )
    }
    .preferredColorScheme(.dark)
}
