import SwiftUI

struct ConversationListView: View {
    @State private var viewModel: ConversationListViewModel
    @State private var presentsNewConversation = false
    @State private var selectedConversation: Conversation?
    private let contactRepository: any ContactRepository

    init(
        viewModel: ConversationListViewModel = ConversationListViewModel(),
        contactRepository: any ContactRepository = InMemoryContactRepository()
    ) {
        _viewModel = State(initialValue: viewModel)
        self.contactRepository = contactRepository
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
                if viewModel.filteredConversations.isEmpty {
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
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.medium))
                                .overlay {
                                    RoundedRectangle(cornerRadius: VeyraRadius.medium)
                                        .stroke(VeyraColor.divider.opacity(0.65), lineWidth: 1)
                                }
                            }
                        }
                        .padding(.horizontal, VeyraSpacing.md)
                        .padding(.bottom, VeyraSpacing.xl)
                    }
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
            MessageTimelineView(conversation: conversation, messages: [])
        }
        .sheet(isPresented: $presentsNewConversation) {
            NewConversationView(viewModel: NewConversationViewModel(repository: contactRepository)) { conversation in
                viewModel.add(conversation)
                selectedConversation = conversation
            }
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.large))
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
