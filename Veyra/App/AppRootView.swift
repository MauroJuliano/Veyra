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
                    viewModel: ConversationListViewModel(repository: dependencies.conversations),
                    contactRepository: dependencies.contacts
                )
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case let .conversation(conversation):
                        MessageTimelineView(conversation: conversation)
                    }
                }
            }
            .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }

            PlaceholderTabView(title: "People", message: "Your contacts will live here.", systemImage: "person.2")
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

private struct PlaceholderTabView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VeyraColor.background)
    }
}

#Preview {
    AppRootView()
}
