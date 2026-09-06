import SwiftUI

struct PublicProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var user: User
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sharedMedia: [Message] = []
    @State private var selectedImage: FullScreenImage?
    @State private var blockRelationship = BlockRelationship()
    @State private var confirmsBlock = false
    @State private var isUpdatingBlock = false
    @State private var showsReport = false
    @State private var reportConfirmation: String?

    let repository: (any RemoteChatRepository)?
    let conversationID: UUID?
    let isActive: Bool?
    var onMessage: ((User) async -> Void)?

    init(
        user: User,
        repository: (any RemoteChatRepository)?,
        conversationID: UUID? = nil,
        isActive: Bool? = nil,
        onMessage: ((User) async -> Void)? = nil
    ) {
        _user = State(initialValue: user)
        self.repository = repository
        self.conversationID = conversationID
        self.isActive = isActive
        self.onMessage = onMessage
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VeyraSpacing.xl) {
                identity
                profileActions
                aboutCard
                sharedMediaCard

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Report user", systemImage: "exclamationmark.bubble", role: .destructive) {
                        showsReport = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Profile actions")
            }
        }
        .task { await loadProfile() }
        .fullScreenCover(item: $selectedImage) { image in
            FullScreenImageView(images: sharedMediaImages, selectedID: image.id) {
                selectedImage = nil
            }
        }
        .confirmationDialog(
            "Block \(user.participantName)?",
            isPresented: $confirmsBlock,
            titleVisibility: .visible
        ) {
            Button("Block user", role: .destructive) {
                Task { await updateBlockState(true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Neither of you will be able to send new messages until you unblock this user.")
        }
        .sheet(isPresented: $showsReport) {
            ReportUserView(user: user, repository: repository) {
                reportConfirmation = "Thanks. Your report was submitted for review."
            }
        }
        .alert("Report submitted", isPresented: reportConfirmationIsPresented) {
            Button("OK") {}
        } message: {
            Text(reportConfirmation ?? "")
        }
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

    private var profileActions: some View {
        VStack(spacing: VeyraSpacing.sm) {
            Button {
                if blockRelationship.isBlockedByMe {
                    Task { await updateBlockState(false) }
                } else if !blockRelationship.isBlockedByThem {
                    Task {
                        if let onMessage {
                            await onMessage(user)
                        } else {
                            dismiss()
                        }
                    }
                }
            } label: {
                Label(primaryActionTitle, systemImage: primaryActionIcon)
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
            .disabled(isUpdatingBlock || blockRelationship.isBlockedByThem)

            if !blockRelationship.preventsMessaging {
                Button(role: .destructive) {
                    confirmsBlock = true
                } label: {
                    Label("Block user", systemImage: "hand.raised.fill")
                        .font(VeyraTypography.caption.weight(.semibold))
                        .frame(height: 40)
                }
                .disabled(isUpdatingBlock)
            }
        }
    }

    private var primaryActionTitle: String {
        if blockRelationship.isBlockedByMe { return "Unblock" }
        if blockRelationship.isBlockedByThem { return "Messaging unavailable" }
        return "Message"
    }

    private var primaryActionIcon: String {
        blockRelationship.isBlockedByMe ? "hand.raised.slash.fill" : "message.fill"
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

    private var sharedMediaCard: some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.md) {
            HStack {
                Label("Shared media", systemImage: "photo.on.rectangle.angled")
                    .font(VeyraTypography.title)
                    .foregroundStyle(VeyraColor.textPrimary)

                Spacer()

                NavigationLink {
                    SharedMediaGalleryView(messages: sharedMedia)
                } label: {
                    Label("See all", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                        .font(VeyraTypography.caption.weight(.semibold))
                        .foregroundStyle(VeyraColor.accent)
                }

            }

            if isLoading && sharedMedia.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 92)
            } else if sharedMedia.isEmpty {
                ContentUnavailableView(
                    "No shared media yet",
                    systemImage: "photo",
                    description: Text("Photos shared in this conversation will appear here.")
                )
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: VeyraSpacing.sm) {
                        ForEach(Array(sharedMedia.prefix(4))) { message in
                            if let url = message.imageURL {
                                Button {
                                    selectedImage = FullScreenImage(
                                        id: message.id,
                                        url: url,
                                        canSave: message.direction == .incoming
                                    )
                                } label: {
                                    VeyraCachedImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 108, height: 108)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Open shared photo")
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VeyraSpacing.lg)
        .background { GlassBackground(cornerRadius: 28, tintOpacity: 0.1, glowOpacity: 0.1) }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var displayedBio: String {
        user.bio.flatMap { $0.isEmpty ? nil : $0 } ?? "No bio yet"
    }

    private var reportConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { reportConfirmation != nil },
            set: { if !$0 { reportConfirmation = nil } }
        )
    }

    private var sharedMediaImages: [FullScreenImage] {
        sharedMedia.compactMap { message in
            message.imageURL.map {
                FullScreenImage(
                    id: message.id,
                    url: $0,
                    canSave: message.direction == .incoming
                )
            }
        }
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
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }

        if let userID = user.participantID {
            do {
                user = try await repository.fetchPublicProfile(userID: userID)
                blockRelationship = try await repository.fetchBlockRelationship(userID: userID)
                errorMessage = nil
            } catch {
                errorMessage = "Unable to refresh this profile."
            }
        }

        if let conversationID {
            do {
                sharedMedia = try await loadAllSharedMedia(
                    conversationID: conversationID,
                    repository: repository
                )
            } catch {
                if errorMessage == nil {
                    errorMessage = "Unable to load shared media."
                }
            }
        }
    }

    @MainActor
    private func updateBlockState(_ shouldBlock: Bool) async {
        guard let repository, let userID = user.participantID else { return }
        isUpdatingBlock = true
        defer { isUpdatingBlock = false }
        do {
            try await repository.setUserBlocked(userID: userID, isBlocked: shouldBlock)
            blockRelationship = try await repository.fetchBlockRelationship(userID: userID)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to update this block setting."
        }
    }

    private func loadAllSharedMedia(
        conversationID: UUID,
        repository: any RemoteChatRepository
    ) async throws -> [Message] {
        var before: Date?
        var media: [Message] = []

        while true {
            let page = try await repository.fetchMessages(
                conversationID: conversationID,
                before: before,
                limit: 100
            )
            media.append(contentsOf: page.filter { $0.imageURL != nil })

            guard page.count == 100, let oldestDate = page.last?.sentAt else { break }
            before = oldestDate
        }

        return media.sorted { $0.sentAt > $1.sentAt }
    }
}

private struct SharedMediaGalleryView: View {
    let messages: [Message]
    @State private var selectedImage: FullScreenImage?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: VeyraSpacing.xs),
        count: 3
    )

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: VeyraSpacing.xs) {
                ForEach(messages) { message in
                    if let url = message.imageURL {
                        Button {
                            selectedImage = FullScreenImage(
                                id: message.id,
                                url: url,
                                canSave: message.direction == .incoming
                            )
                        } label: {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    VeyraCachedImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                                    .allowsHitTesting(false)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Open shared photo")
                    }
                }
            }
            .padding(VeyraSpacing.md)
        }
        .background(VeyraColor.background.ignoresSafeArea())
        .navigationTitle("Shared media")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(item: $selectedImage) { image in
            FullScreenImageView(images: galleryImages, selectedID: image.id) {
                selectedImage = nil
            }
        }
    }

    private var galleryImages: [FullScreenImage] {
        messages.compactMap { message in
            message.imageURL.map {
                FullScreenImage(
                    id: message.id,
                    url: $0,
                    canSave: message.direction == .incoming
                )
            }
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
