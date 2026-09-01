import SwiftUI

struct AppRootView: View {
    private let dependencies: AppDependencies
    @State private var authentication: AuthenticationCoordinator

    init(
        dependencies: AppDependencies = AppDependencies(),
        authenticationService: any AuthenticationService = AuthenticationServiceFactory.make()
    ) {
        self.dependencies = dependencies
        _authentication = State(initialValue: AuthenticationCoordinator(service: authenticationService))
    }

    var body: some View {
        switch authentication.route {
        case .authenticated:
            authenticatedContent
                .transition(.opacity)
        case .registration:
            RegistrationView(
                isLoading: authentication.isLoading,
                externalError: authentication.errorMessage,
                onBack: authentication.showLogin,
                onRegistered: { name, email, password in
                    Task { await authentication.signUp(name: name, email: email, password: password) }
                }
            )
            .transition(.opacity)
        case .login:
            LoginView(
                isLoading: authentication.isLoading,
                externalError: authentication.errorMessage,
                onAuthenticated: { email, password in
                    Task { await authentication.signIn(email: email, password: password) }
                },
                onCreateAccount: authentication.showRegistration
            )
            .transition(.opacity)
        case let .emailConfirmation(email):
            EmailConfirmationView(email: email, onBack: authentication.showLogin)
                .transition(.opacity)
        }
    }

    private var authenticatedContent: some View {
        TabView {
            NavigationStack {
                ConversationListView(
                    viewModel: ConversationListViewModel(repository: dependencies.conversations, remoteRepository: dependencies.remoteChat)
                )
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case let .conversation(conversation):
                        MessageTimelineView(conversation: conversation, repository: dependencies.remoteChat)
                    }
                }
            }
            .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }

            NavigationStack {
                ContactListView(repository: dependencies.remoteChat)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case let .conversation(conversation):
                            MessageTimelineView(conversation: conversation, repository: dependencies.remoteChat)
                        }
                    }
            }
                .tabItem { Label("People", systemImage: "person.2.fill") }

            ProfileView(onLogout: { Task { await authentication.signOut() } })
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .tint(VeyraColor.accent)
        .toolbarBackground(VeyraColor.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }

}

private struct ContactListView: View {
    let repository: (any RemoteChatRepository)?
    @State private var contacts: [Contact] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && contacts.isEmpty {
                ProgressView("Loading contacts…")
            } else if contacts.isEmpty {
                ContentUnavailableView(
                    "No contacts yet",
                    systemImage: "person.2",
                    description: Text(errorMessage ?? "People you start conversations with will appear here.")
                )
            } else {
                List(contacts) { contact in
                    if let conversationID = contact.conversationID {
                        NavigationLink(value: AppRoute.conversation(
                            Conversation(id: conversationID, participantID: contact.id, participantName: contact.name, lastMessage: "", updatedAt: .now, isOnline: contact.isOnline)
                        )) {
                            contactRow(contact)
                        }
                    } else {
                        contactRow(contact)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("People")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VeyraColor.background)
        .task { await load() }
    }

    private func contactRow(_ contact: Contact) -> some View {
        HStack(spacing: VeyraSpacing.md) {
            VeyraAvatar(name: contact.name, showsOnlineIndicator: contact.isOnline)
            Text(contact.name)
                .font(VeyraTypography.bodyEmphasized)
                .foregroundStyle(VeyraColor.textPrimary)
        }
        .padding(.vertical, VeyraSpacing.xs)
        .listRowBackground(VeyraColor.surface)
    }

    @MainActor
    private func load() async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            contacts = try await repository.fetchContacts()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AppRootView()
}
