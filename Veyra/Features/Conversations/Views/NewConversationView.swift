import SwiftUI

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    let onSubmit: (String) async -> String?
    @State private var viewModel = ConversationListViewModel()

    init(onSubmit: @escaping (String) async -> String?) {
        self.onSubmit = onSubmit
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: VeyraSpacing.lg) {
                searchField
                    .padding(.top, VeyraSpacing.sm)

                Text("Recent searches")

                RecentConversationListView(users: RecentConversationPreviewData.users)

                VeyraTextField(title: "Email", placeholder: "friend@example.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .font(VeyraTypography.caption)
                        .foregroundStyle(VeyraColor.danger)
                }

                VeyraPrimaryButton(title: isLoading ? "Starting…" : "Start conversation") {
                    Task {
                        isLoading = true
                        errorMessage = await onSubmit(email.trimmingCharacters(in: .whitespacesAndNewlines))
                        isLoading = false
                    }
                }
                .disabled(!isValidEmail || isLoading)
                .opacity(isValidEmail && !isLoading ? 1 : 0.55)

                Spacer()
            }
            .padding(VeyraSpacing.lg)
            .contentShape(Rectangle())
            .dismissKeyboardOnTap()
            .background(VeyraColor.background.ignoresSafeArea())
            .navigationTitle("Say hello")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .tint(VeyraColor.accent)
    }

    private var searchField: some View {
        HStack(spacing: VeyraSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(VeyraColor.textSecondary)
            TextField("Search by username or name", text: $viewModel.searchText)
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

    private var isValidEmail: Bool { email.contains("@") && email.contains(".") }
}

#Preview { NewConversationView(onSubmit: { _ in nil }) }
