import SwiftUI

struct BlockedUsersView: View {
    let repository: (any RemoteChatRepository)?
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var userBeingUpdated: UUID?

    var body: some View {
        Group {
            if isLoading && users.isEmpty {
                ProgressView("Loading blocked users…")
            } else if users.isEmpty {
                ContentUnavailableView(
                    "No blocked users",
                    systemImage: "hand.raised",
                    description: Text("People you block will appear here so you can unblock them later.")
                )
            } else {
                List(users) { user in
                    HStack(spacing: VeyraSpacing.md) {
                        VeyraAvatar(name: user.participantName, imageURL: user.participantAvatarURL)

                        VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                            Text(user.participantName)
                                .font(VeyraTypography.bodyEmphasized)
                            Text(user.userName)
                                .font(VeyraTypography.caption)
                                .foregroundStyle(VeyraColor.textSecondary)
                        }

                        Spacer()

                        Button("Unblock") {
                            Task { await unblock(user) }
                        }
                        .font(VeyraTypography.caption.weight(.semibold))
                        .disabled(userBeingUpdated != nil)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VeyraColor.background.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await load() }
        .alert("Privacy", isPresented: errorIsPresented) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    @MainActor
    private func load() async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            users = try await repository.fetchBlockedUsers()
        } catch {
            errorMessage = "Unable to load blocked users."
        }
    }

    @MainActor
    private func unblock(_ user: User) async {
        guard let repository, let userID = user.participantID else { return }
        userBeingUpdated = user.id
        defer { userBeingUpdated = nil }
        do {
            try await repository.setUserBlocked(userID: userID, isBlocked: false)
            users.removeAll { $0.id == user.id }
        } catch {
            errorMessage = "Unable to unblock this user."
        }
    }
}

#Preview {
    NavigationStack { BlockedUsersView(repository: nil) }
        .preferredColorScheme(.dark)
}
