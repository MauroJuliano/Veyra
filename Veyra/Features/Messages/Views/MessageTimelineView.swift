import SwiftUI
import PhotosUI

struct MessageTimelineView: View {
    let conversation: Conversation
    @State private var viewModel: MessageTimelineViewModel
    @State private var messagePendingDeletion: Message?
    @State private var selectedPhoto: PhotosPickerItem?

    init(conversation: Conversation, repository: (any RemoteChatRepository)? = nil, messages: [Message]? = nil) {
        self.conversation = conversation
        _viewModel = State(initialValue: MessageTimelineViewModel(
            conversationID: conversation.id,
            participantID: conversation.participantID,
            isParticipantActive: conversation.isOnline,
            participantLastSeenAt: conversation.lastSeenAt,
            repository: repository,
            messages: messages ?? (repository == nil ? MessagePreviewData.messages(for: conversation) : [])
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: VeyraSpacing.sm) {
                    if viewModel.isLoading { ProgressView().padding() }
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
                            MessageBubbleView(message: message, participantName: conversation.participantName)
                                .contextMenu {
                                    if message.direction == .outgoing {
                                        Button("Delete message", systemImage: "trash", role: .destructive) {
                                            messagePendingDeletion = message
                                        }
                                    }
                                }
                        }
                    }
                }
                .padding(VeyraSpacing.md)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()

            Divider().overlay(VeyraColor.divider)
            if viewModel.isParticipantTyping {
                HStack(spacing: VeyraSpacing.sm) {
                    VeyraAvatar(name: conversation.participantName, size: .small)
                    Text("\(conversation.participantName) is typing…")
                        .font(VeyraTypography.caption)
                        .foregroundStyle(VeyraColor.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, VeyraSpacing.md)
                .padding(.top, VeyraSpacing.sm)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            MessageComposerView(text: $viewModel.draft, canSend: viewModel.canSend && !viewModel.isSending, selectedPhoto: $selectedPhoto) {
                Task { await viewModel.send() }
            }
        }
        .background {
            LinearGradient(
                colors: [VeyraColor.accentMuted.opacity(0.55), VeyraColor.background, VeyraColor.background],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(VeyraColor.surface.opacity(0.96), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: VeyraSpacing.sm) {
                    VeyraAvatar(name: conversation.participantName, size: .small, showsOnlineIndicator: viewModel.isParticipantActive)
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
        .task { await viewModel.observeMessages() }
        .onChange(of: viewModel.draft) { _, _ in viewModel.draftDidChange() }
        .onChange(of: selectedPhoto) { _, item in
            sendSelectedPhoto(item)
        }
        .onDisappear { Task { await viewModel.stopTyping() } }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isParticipantTyping)
        .alert("Delete message?", isPresented: deletionAlertIsPresented, presenting: messagePendingDeletion) { message in
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(message) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This message will be removed for everyone in the conversation.")
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
            if let data = try? await item.loadTransferable(type: Data.self) {
                await viewModel.sendImage(data)
            }
            selectedPhoto = nil
        }
    }
}

#Preview("Timeline - Dark") {
    NavigationStack {
        MessageTimelineView(conversation: ConversationPreviewData.conversations[0])
    }
    .preferredColorScheme(.dark)
}
