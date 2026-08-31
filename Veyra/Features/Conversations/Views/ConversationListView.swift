import SwiftUI

struct ConversationListView: View {
    @State private var viewModel: ConversationListViewModel
    @State private var presentsNewConversation = false
    @State private var selectedConversation: Conversation?

    init(viewModel: ConversationListViewModel = ConversationListViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.filteredConversations.isEmpty {
                ContentUnavailableView {
                    Label(viewModel.hasSearchQuery ? "No conversations found" : "No conversations yet", systemImage: viewModel.hasSearchQuery ? "magnifyingglass" : "message")
                } description: {
                    Text(viewModel.hasSearchQuery ? "Try another name or message." : "Your conversations will appear here.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredConversations) { conversation in
                            NavigationLink(value: AppRoute.conversation(conversation)) {
                                ConversationRowView(conversation: conversation)
                            }
                            .buttonStyle(.plain)
                            if conversation.id != viewModel.filteredConversations.last?.id {
                                Divider().overlay(VeyraColor.divider).padding(.leading, 76)
                            }
                        }
                    }
                    .background(VeyraColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.large))
                    .padding(.horizontal, VeyraSpacing.md)
                    .padding(.bottom, VeyraSpacing.xl)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VeyraColor.background)
        .navigationTitle("Messages")
        .searchable(text: $viewModel.searchText, prompt: "Search conversations")
        .navigationDestination(item: $selectedConversation) { conversation in
            MessageTimelineView(conversation: conversation, messages: [])
        }
        .sheet(isPresented: $presentsNewConversation) {
            NewConversationView { conversation in
                viewModel.add(conversation)
                selectedConversation = conversation
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { presentsNewConversation = true } label: { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel("New conversation")
            }
        }
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
