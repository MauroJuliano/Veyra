import SwiftUI

struct ConversationListView: View {
    @State private var viewModel: ConversationListViewModel
    @State private var presentsNewConversation = false
    @State private var selectedConversation: Conversation?
    @State private var conversationPendingDeletion: Conversation?
    private let messageCache: any MessageCacheRepository
    private let callRepository: (any CallRepository)?

    init(
        viewModel: ConversationListViewModel = ConversationListViewModel(),
        messageCache: any MessageCacheRepository = InMemoryMessageCacheRepository(),
        callRepository: (any CallRepository)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.messageCache = messageCache
        self.callRepository = callRepository
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
            }
            .padding(.horizontal, VeyraSpacing.md)
            .padding(.top, VeyraSpacing.xl)
            .padding(.bottom, VeyraSpacing.md)

            Group {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: VeyraSpacing.sm) {
                            ForEach(0..<5, id: \.self) { _ in VeyraSkeletonRow() }
                        }
                        .padding(.horizontal, VeyraSpacing.md)
                    }
                    .accessibilityLabel("Loading conversations…")
                } else if viewModel.filteredConversations.isEmpty {
                    ContentUnavailableView {
                        Label(LocalizedStringKey(viewModel.hasSearchQuery ? "No conversations found" : "No conversations yet"), systemImage: viewModel.hasSearchQuery ? "magnifyingglass" : "message")
                    } description: {
                        Text(LocalizedStringKey(viewModel.hasSearchQuery ? "Try another name or message." : "Your conversations will appear here."))
                    }
                } else {
                    List {
                        ForEach(viewModel.filteredConversations) { conversation in
                            Button {
                                selectedConversation = conversation
                            } label: {
                                ConversationRowView(conversation: conversation)
                            }
                            .buttonStyle(.plain)
                            .background { GlassBackground() }
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .listRowInsets(
                                EdgeInsets(
                                    top: VeyraSpacing.xs,
                                    leading: VeyraSpacing.md,
                                    bottom: VeyraSpacing.xs,
                                    trailing: VeyraSpacing.md
                                )
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    conversationPendingDeletion = conversation
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.top, 0, for: .scrollContent)
                    .contentMargins(.bottom, VeyraSpacing.xl, for: .scrollContent)
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
            MessageTimelineView(conversation: conversation, repository: viewModel.chatRepository, callRepository: callRepository, cache: messageCache, messages: [])
        }
        .sheet(isPresented: $presentsNewConversation) {
            NewConversationView(repository: viewModel.chatRepository) { user in
                if let conversation = await viewModel.startConversation(user: user) {
                    presentsNewConversation = false
                    selectedConversation = conversation
                    return nil
                }
                return viewModel.errorMessage ?? AppLocalization.string("Unable to start this conversation.")
            }
        }
        .task { await viewModel.observeConversations() }
        .alert(
            AppLocalization.string("Delete conversation?", table: "Deletion"),
            isPresented: deletionAlertIsPresented,
            presenting: conversationPendingDeletion
        ) { conversation in
            Button(AppLocalization.string("Delete for me", table: "Deletion"), role: .destructive) {
                Task { await viewModel.delete(conversation) }
            }
            Button(AppLocalization.string("Cancel", table: "Deletion"), role: .cancel) {}
        } message: { conversation in
            Text(
                AppLocalization.string(
                    "The conversation with \(conversation.participantName) will be removed only for you. It will appear again if a new message arrives.",
                    table: "Deletion"
                )
            )
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Chats")
                    .font(VeyraTypography.title)
                    .foregroundStyle(VeyraColor.textPrimary)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button { presentsNewConversation = true } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
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
