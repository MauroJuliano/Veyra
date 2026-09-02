import SwiftUI
import PhotosUI
import Photos
import UIKit

struct MessageTimelineView: View {
    let conversation: Conversation
    @State private var viewModel: MessageTimelineViewModel
    @State private var messagePendingDeletion: Message?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: FullScreenImage?
    @State private var messageShowingActions: Message?

    init(conversation: Conversation, repository: (any RemoteChatRepository)? = nil, cache: any MessageCacheRepository = InMemoryMessageCacheRepository(), messages: [Message]? = nil) {
        self.conversation = conversation
        _viewModel = State(initialValue: MessageTimelineViewModel(
            conversationID: conversation.id,
            participantID: conversation.participantID,
            isParticipantActive: conversation.isOnline,
            participantLastSeenAt: conversation.lastSeenAt,
            repository: repository,
            cache: cache,
            messages: messages ?? (repository == nil ? MessagePreviewData.messages(for: conversation) : [])
        ))
    }

    var body: some View {
        chatContent
            .background { chatBackground }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(VeyraColor.surface.opacity(0.96), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { chatToolbar }
            .task { await viewModel.observeMessages() }
            .onChange(of: viewModel.draft) { _, _ in viewModel.draftDidChange() }
            .onChange(of: selectedPhoto) { _, item in sendSelectedPhoto(item) }
            .onDisappear { Task { await viewModel.stopTyping() } }
            .animation(.easeInOut(duration: 0.2), value: viewModel.isParticipantTyping)
            .alert("Delete message?", isPresented: deletionAlertIsPresented, presenting: messagePendingDeletion) { message in
                Button("Delete", role: .destructive) { Task { await viewModel.delete(message) } }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("This message will be removed for everyone in the conversation.")
            }
            .fullScreenCover(item: $selectedImage) { image in
                FullScreenImageView(url: image.url, canSave: image.canSave) { selectedImage = nil }
            }
            .overlay {
                if let message = messageShowingActions {
                    MessageActionsOverlay(
                        message: message,
                        onReact: { emoji in
                            messageShowingActions = nil
                            Task { await viewModel.toggleReaction(emoji, on: message) }
                        },
                        onReply: {
                            viewModel.beginReply(to: message)
                            messageShowingActions = nil
                        },
                        onCopy: {
                            UIPasteboard.general.string = message.text
                            messageShowingActions = nil
                        },
                        onDelete: {
                            messagePendingDeletion = message
                            messageShowingActions = nil
                        },
                        onDismiss: { messageShowingActions = nil }
                    )
                    .transition(.opacity)
                }
            }
    }

    private var chatContent: some View {
        VStack(spacing: 0) {
            messageList
            Divider().overlay(VeyraColor.divider)
            typingIndicator
            replyComposerPreview
            MessageComposerView(
                text: $viewModel.draft,
                canSend: viewModel.canSend && !viewModel.isSending,
                onSend: { Task { await viewModel.send() } },
                selectedPhoto: $selectedPhoto,
                onSendSticker: { sticker in Task { await viewModel.sendSticker(sticker) } },
                isReplying: viewModel.replyingTo != nil
            )
        }
    }

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: VeyraSpacing.sm) {
                if viewModel.isLoading { ProgressView().padding() }
                if viewModel.hasEarlierMessages && !viewModel.messages.isEmpty {
                    Button {
                        Task { await viewModel.loadEarlierMessages() }
                    } label: {
                        if viewModel.isLoadingEarlier {
                            ProgressView()
                        } else {
                            Label("Load earlier messages", systemImage: "clock.arrow.circlepath")
                        }
                    }
                    .font(VeyraTypography.caption)
                    .foregroundStyle(VeyraColor.accent)
                    .disabled(viewModel.isLoadingEarlier)
                    .padding(.vertical, VeyraSpacing.sm)
                }
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(VeyraTypography.caption).foregroundStyle(VeyraColor.danger)
                }
                ForEach(viewModel.days) { day in
                    Text(day.date, format: .dateTime.day().month(.wide))
                        .font(VeyraTypography.caption)
                        .foregroundStyle(VeyraColor.textPrimary)
                        .padding(.horizontal, VeyraSpacing.md)
                        .padding(.vertical, VeyraSpacing.xs)
                        .background(VeyraColor.surfaceElevated)
                        .clipShape(Capsule())
                        .padding(.vertical, VeyraSpacing.md)
                    ForEach(day.messages) { message in
                        MessageBubbleView(
                            message: message,
                            participantName: conversation.participantName,
                            participantAvatarURL: conversation.participantAvatarURL,
                            onReply: { viewModel.beginReply(to: message) }
                        ) { url in
                            selectedImage = FullScreenImage(url: url, canSave: message.direction == .incoming)
                        }
                            .onLongPressGesture(minimumDuration: 0.35) {
                                withAnimation(.easeOut(duration: 0.18)) { messageShowingActions = message }
                            }
                    }
                }
            }
            .padding(VeyraSpacing.md)
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }

    @ViewBuilder private var replyComposerPreview: some View {
        if let message = viewModel.replyingTo {
            HStack(spacing: 0) {
                Rectangle().fill(VeyraColor.accent).frame(width: 4, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.direction == .outgoing ? "You" : conversation.participantName)
                        .font(VeyraTypography.bodyEmphasized)
                        .foregroundStyle(VeyraColor.accent)
                    Text(message.imageURL == nil ? message.text : "Photo")
                        .font(VeyraTypography.body)
                        .foregroundStyle(VeyraColor.textPrimary.opacity(0.9))
                        .lineLimit(1)
                }
                .padding(.horizontal, VeyraSpacing.md)
                .padding(.vertical, VeyraSpacing.sm)
                Spacer()
                Button { viewModel.cancelReply() } label: {
                    Image(systemName: "xmark.circle")
                        .font(.title)
                        .foregroundStyle(VeyraColor.textPrimary)
                }
                    .accessibilityLabel("Cancel reply")
                    .padding(.trailing, VeyraSpacing.md)
            }
            .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .leading)
            .background(VeyraColor.surfaceElevated.opacity(0.98))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder private var typingIndicator: some View {
        if viewModel.isParticipantTyping {
            HStack(spacing: VeyraSpacing.sm) {
                VeyraAvatar(name: conversation.participantName, imageURL: conversation.participantAvatarURL, size: .small)
                Text("\(conversation.participantName) is typing…")
                    .font(VeyraTypography.caption)
                    .foregroundStyle(VeyraColor.textSecondary)
                Spacer()
            }
            .padding(.horizontal, VeyraSpacing.md)
            .padding(.top, VeyraSpacing.sm)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var chatBackground: some View {
        LinearGradient(colors: [VeyraColor.accentMuted.opacity(0.55), VeyraColor.background, VeyraColor.background], startPoint: .topTrailing, endPoint: .bottomLeading)
            .ignoresSafeArea()
    }

    @ToolbarContentBuilder private var chatToolbar: some ToolbarContent {
            ToolbarItem(placement: .principal) {
                HStack(spacing: VeyraSpacing.sm) {
                    VeyraAvatar(name: conversation.participantName, imageURL: conversation.participantAvatarURL, size: .small, showsOnlineIndicator: viewModel.isParticipantActive)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(conversation.participantName)
                            .font(VeyraTypography.bodyEmphasized)
                            .foregroundStyle(VeyraColor.textPrimary)
                        Text(participantStatus)
                            .font(VeyraTypography.caption)
                            .foregroundStyle(VeyraColor.textSecondary)
                    }
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: {}) { Image(systemName: "phone") }
                    .accessibilityLabel("Start audio call")
                Button(action: {}) { Image(systemName: "video") }
                    .accessibilityLabel("Start video call")
            }
    }

    private var deletionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { messagePendingDeletion != nil },
            set: { if !$0 { messagePendingDeletion = nil } }
        )
    }

    private var participantStatus: String {
        if viewModel.isParticipantActive { return "Active" }
        guard let lastSeenAt = viewModel.participantLastSeenAt else { return "Offline" }
        return "Last seen at \(lastSeenAt.formatted(date: .omitted, time: .shortened))"
    }

    private func sendSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw ImageSelectionError.noData
                }
                await viewModel.sendImage(data)
            } catch {
                viewModel.reportImageSelectionError(error)
            }
            selectedPhoto = nil
        }
    }
}

private struct MessageActionsOverlay: View {
    let message: Message
    let onReact: (String) -> Void
    let onReply: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void
    private let emojis = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.32))
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: VeyraSpacing.md) {
                reactionBar
                actionMenu
            }
            .padding(.horizontal, VeyraSpacing.lg)
        }
    }

    private var reactionBar: some View {
        HStack(spacing: VeyraSpacing.sm) {
            ForEach(emojis, id: \.self) { emoji in
                Button { onReact(emoji) } label: {
                    Text(emoji).font(.system(size: 29))
                        .frame(width: 38, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("React with \(emoji)")
            }
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
        }
        .padding(.horizontal, VeyraSpacing.sm)
        .padding(.vertical, VeyraSpacing.xs)
        .background(Color.black.opacity(0.78))
        .clipShape(Capsule())
    }

    private var actionMenu: some View {
        VStack(spacing: 0) {
            actionButton("Reply", icon: "arrowshape.turn.up.left", action: onReply)
            Divider().overlay(Color.white.opacity(0.1))
            if message.imageURL == nil {
                actionButton("Copy", icon: "doc.on.doc", action: onCopy)
                Divider().overlay(Color.white.opacity(0.1))
            }
            if message.direction == .outgoing {
                actionButton("Delete", icon: "trash", color: VeyraColor.danger, action: onDelete)
            }
        }
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: 310)
    }

    private func actionButton(_ title: String, icon: String, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: icon)
            }
            .font(VeyraTypography.body)
            .foregroundStyle(color)
            .padding(VeyraSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private enum ImageSelectionError: LocalizedError {
    case noData

    var errorDescription: String? { "The selected image could not be loaded." }
}

private struct FullScreenImage: Identifiable {
    let id = UUID()
    let url: URL
    let canSave: Bool
}

private struct FullScreenImageView: View {
    let url: URL
    let canSave: Bool
    let dismiss: () -> Void
    @State private var isSaving = false
    @State private var saveMessage: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea().onTapGesture(perform: dismiss)
            VeyraCachedImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView().tint(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: VeyraSpacing.md) {
                if canSave {
                    Button { Task { await saveToPhotoLibrary() } } label: {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                    }
                    .disabled(isSaving)
                    .accessibilityLabel("Save image to photos")
                }
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                }
            }
            .font(.largeTitle)
            .foregroundStyle(.white)
            .padding()
        }
        .alert("Photo", isPresented: saveAlertIsPresented) {
            Button("OK") {}
        } message: {
            Text(saveMessage ?? "")
        }
    }

    private var saveAlertIsPresented: Binding<Bool> {
        Binding(get: { saveMessage != nil }, set: { if !$0 { saveMessage = nil } })
    }

    @MainActor
    private func saveToPhotoLibrary() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                saveMessage = "Allow photo access in Settings to save received images."
                return
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            try await saveImageData(data)
            saveMessage = "Image saved to Photos."
        } catch {
            saveMessage = "The image could not be saved. \(error.localizedDescription)"
        }
    }

    private func saveImageData(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: PhotoSaveError.unknownFailure)
                }
            }
        }
    }
}

private enum PhotoSaveError: LocalizedError {
    case unknownFailure

    var errorDescription: String? {
        "Photos did not complete the save operation."
    }
}

#Preview("Timeline - Dark") {
    NavigationStack {
        MessageTimelineView(conversation: ConversationPreviewData.conversations[0])
    }
    .preferredColorScheme(.dark)
}
