import SwiftUI

struct MessageTimelineView: View {
    let conversation: Conversation
    @State private var viewModel: MessageTimelineViewModel

    init(conversation: Conversation, repository: (any RemoteChatRepository)? = nil, messages: [Message]? = nil) {
        self.conversation = conversation
        _viewModel = State(initialValue: MessageTimelineViewModel(
            conversationID: conversation.id,
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
                        }
                    }
                }
                .padding(VeyraSpacing.md)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)

            Divider().overlay(VeyraColor.divider)
            MessageComposerView(text: $viewModel.draft, canSend: viewModel.canSend && !viewModel.isSending) {
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
                    VeyraAvatar(name: conversation.participantName, size: .small, showsOnlineIndicator: conversation.isOnline)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(conversation.participantName)
                            .font(VeyraTypography.bodyEmphasized)
                            .foregroundStyle(VeyraColor.textPrimary)
                        Text(conversation.isOnline ? "Online" : "Offline")
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
    }
}

#Preview("Timeline - Dark") {
    NavigationStack {
        MessageTimelineView(conversation: ConversationPreviewData.conversations[0])
    }
    .preferredColorScheme(.dark)
}
