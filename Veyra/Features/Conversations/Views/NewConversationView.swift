import SwiftUI

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NewConversationViewModel
    let onSelect: (Conversation) -> Void

    init(viewModel: NewConversationViewModel = NewConversationViewModel(), onSelect: @escaping (Conversation) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.filteredContacts.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    List(viewModel.filteredContacts) { contact in
                        Button {
                            onSelect(viewModel.conversation(for: contact))
                            dismiss()
                        } label: {
                            HStack(spacing: VeyraSpacing.md) {
                                VeyraAvatar(name: contact.name, showsOnlineIndicator: contact.isOnline)
                                Text(contact.name)
                                    .font(VeyraTypography.bodyEmphasized)
                                    .foregroundStyle(VeyraColor.textPrimary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("New message")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(VeyraColor.accent)
    }
}

#Preview("New conversation") {
    NewConversationView(onSelect: { _ in })
}

#Preview("No contacts") {
    NewConversationView(viewModel: NewConversationViewModel(contacts: []), onSelect: { _ in })
}
