import SwiftUI

struct ConversationListView: View {
    @State private var viewModel: ConversationListViewModel
    @State private var presentsNewConversation = false
    @State private var selectedConversation: Conversation?
    @State private var conversationPendingDeletion: Conversation?
    private let messageCache: any MessageCacheRepository

    init(
        viewModel: ConversationListViewModel = ConversationListViewModel(),
        messageCache: any MessageCacheRepository = InMemoryMessageCacheRepository()
    ) {
        _viewModel = State(initialValue: viewModel)
        self.messageCache = messageCache
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, VeyraSpacing.md)
                .padding(.top, VeyraSpacing.sm)

            HStack {
                Text("Messages")
                    .font(VeyraTypography.title)
                    .foregroundStyle(VeyraColor.textPrimary)
                Spacer()
                Text("Recent")
                    .font(VeyraTypography.body)
                    .foregroundStyle(VeyraColor.textSecondary)
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(VeyraColor.textSecondary)
            }
            .padding(.horizontal, VeyraSpacing.md)
            .padding(.top, VeyraSpacing.xl)
            .padding(.bottom, VeyraSpacing.md)

            Group {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView("Loading conversations…")
                } else if viewModel.filteredConversations.isEmpty {
                    ContentUnavailableView {
                        Label(viewModel.hasSearchQuery ? "No conversations found" : "No conversations yet", systemImage: viewModel.hasSearchQuery ? "magnifyingglass" : "message")
                    } description: {
                        Text(viewModel.hasSearchQuery ? "Try another name or message." : "Your conversations will appear here.")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: VeyraSpacing.sm) {
                            ForEach(viewModel.filteredConversations) { conversation in
                                NavigationLink(value: AppRoute.conversation(conversation)) {
                                    ConversationRowView(conversation: conversation)
                                }
                                .buttonStyle(.plain)
                                .background { GlassBackground() }
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        conversationPendingDeletion = conversation
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, VeyraSpacing.md)
                        .padding(.bottom, VeyraSpacing.xl)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .dismissKeyboardOnTap()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [VeyraColor.background, VeyraColor.accentMuted.opacity(0.5), VeyraColor.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedConversation) { conversation in
            MessageTimelineView(conversation: conversation, repository: viewModel.chatRepository, cache: messageCache, messages: [])
        }
        .sheet(isPresented: $presentsNewConversation) {
            NewConversationView(repository: viewModel.chatRepository) { user in
                if let conversation = await viewModel.startConversation(user: user) {
                    presentsNewConversation = false
                    selectedConversation = conversation
                    return nil
                }
                return viewModel.errorMessage ?? "Unable to start this conversation."
            }
        }
        .task { await viewModel.observeConversations() }
        .alert("Delete conversation?", isPresented: deletionAlertIsPresented, presenting: conversationPendingDeletion) { conversation in
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(conversation) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { conversation in
            Text("The conversation with \(conversation.participantName) and all of its messages will be removed for both participants.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                VeyraAvatar(name: "Mauro Juliano", size: .small)
            }

            ToolbarItem(placement: .principal) {
                Text("Chats")
                    .font(VeyraTypography.title)
                    .foregroundStyle(VeyraColor.textPrimary)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button { presentsNewConversation = true } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 36, height: 36)
                        .background(VeyraColor.surfaceElevated)
                        .clipShape(Circle())
                }
                    .accessibilityLabel("New conversation")
            }
        }
    }

    private var deletionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { conversationPendingDeletion != nil },
            set: { if !$0 { conversationPendingDeletion = nil } }
        )
    }

    private var searchField: some View {
        HStack(spacing: VeyraSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(VeyraColor.textSecondary)
            TextField("Search messages", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(VeyraColor.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, VeyraSpacing.md)
        .frame(minHeight: 52)
        .background { GlassBackground(glowOpacity: 0.1) }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview("Conversations - Light") {
    NavigationStack { ConversationListView() }.preferredColorScheme(.light)
}

#Preview("Conversations - Dark") {
    NavigationStack { ConversationListView() }.preferredColorScheme(.dark)
}

#Preview("Empty conversations") {
    NavigationStack { ConversationListView(viewModel: ConversationListViewModel(conversations: [])) }
}
