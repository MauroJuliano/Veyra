import SwiftUI

struct ConversationListView: View {
    @State private var viewModel: ConversationListViewModel

    init(viewModel: ConversationListViewModel = ConversationListViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink(value: AppRoute.conversation(conversation)) {
                        ConversationRowView(conversation: conversation)
                    }
                    .buttonStyle(.plain)

                    if conversation.id != viewModel.conversations.last?.id {
                        Divider()
                            .overlay(VeyraColor.divider)
                            .padding(.leading, 76)
                    }
                }
            }
            .background(VeyraColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.large))
            .padding(.horizontal, VeyraSpacing.md)
            .padding(.bottom, VeyraSpacing.xl)
        }
        .background(VeyraColor.background)
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New conversation")
            }
        }
    }
}

#Preview("Conversations - Light") {
    NavigationStack { ConversationListView() }
        .preferredColorScheme(.light)
}

#Preview("Conversations - Dark") {
    NavigationStack { ConversationListView() }
        .preferredColorScheme(.dark)
}
