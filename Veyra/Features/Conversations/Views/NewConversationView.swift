import SwiftUI

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NewConversationViewModel
    @State private var openingUserID: UUID?
    @State private var selectedUser: User?
    @State private var startError: String?
    let onSelect: (User) async -> String?

    init(repository: (any RemoteChatRepository)? = nil, onSelect: @escaping (User) async -> String?) {
        _viewModel = State(initialValue: NewConversationViewModel(repository: repository))
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VeyraSpacing.lg) {
                    searchField
                    content
                    if let message = startError ?? viewModel.errorMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(VeyraTypography.caption)
                            .foregroundStyle(VeyraColor.danger)
                    }
                }
                .padding(VeyraSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .background(VeyraColor.background.ignoresSafeArea())
            .navigationTitle("Find new people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .navigationDestination(item: $selectedUser) { user in
                PublicProfileView(user: user, repository: viewModel.profileRepository) { selected in
                    open(selected)
                }
            }
        }
        .tint(VeyraColor.accent)
        .task(id: viewModel.searchText) { await viewModel.search() }
    }

    @ViewBuilder private var content: some View {
        if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
            if viewModel.isSearching && viewModel.results.isEmpty {
                LazyVStack(spacing: VeyraSpacing.sm) {
                    ForEach(0..<4, id: \.self) { _ in VeyraSkeletonRow() }
                }
                .accessibilityLabel("Searching…")
            } else if viewModel.results.isEmpty && viewModel.errorMessage == nil {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else {
                Text("People").font(VeyraTypography.title)
                RecentConversationListView(users: viewModel.results, showsRemoveButtons: false, onSelect: showProfile)
            }
        } else if !viewModel.recentUsers.isEmpty {
            Text("Recent searches").font(VeyraTypography.title)
            RecentConversationListView(users: viewModel.recentUsers, onSelect: showProfile, onRemove: viewModel.removeRecent)
        } else {
            ContentUnavailableView("Find new people", systemImage: "person.badge.plus", description: Text("Search by name or username."))
        }
    }

    private var searchField: some View {
        HStack(spacing: VeyraSpacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(VeyraColor.textSecondary)
            TextField("Search by username or name", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(VeyraColor.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, VeyraSpacing.md)
        .frame(minHeight: 52)
        .background { GlassBackground(glowOpacity: 0.1) }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func open(_ user: User) {
        guard openingUserID == nil else { return }
        openingUserID = user.id
        Task {
            startError = await onSelect(user)
            if startError == nil {
                viewModel.addRecent(user)
                dismiss()
            }
            openingUserID = nil
        }
    }

    private func showProfile(_ user: User) {
        selectedUser = user
    }
}

#Preview { NewConversationView(onSelect: { _ in nil }) }
