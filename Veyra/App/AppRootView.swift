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
                onRegistered: { name, username, email, password in
                    Task { await authentication.signUp(name: name, username: username, email: email, password: password) }
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
                    viewModel: ConversationListViewModel(repository: dependencies.conversations, remoteRepository: dependencies.remoteChat),
                    messageCache: dependencies.messageCache
                )
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case let .conversation(conversation):
                        MessageTimelineView(conversation: conversation, repository: dependencies.remoteChat, cache: dependencies.messageCache)
                    }
                }
            }
            .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }

            NavigationStack {
                ContactListView(repository: dependencies.remoteChat, localRepository: dependencies.contacts, messageCache: dependencies.messageCache)
            }
                .tabItem { Label("Connections", systemImage: "person.2.fill") }

            ProfileView(viewModel: ProfileViewModel(remoteRepository: dependencies.remoteChat), onLogout: {
                Task {
                    if let token = UserDefaults.standard.string(forKey: PushNotificationRegistration.tokenKey) {
                        try? await dependencies.remoteChat?.unregisterPushToken(token)
                    }
                    await authentication.signOut()
                }
            })
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .tint(VeyraColor.accent)
        .toolbarBackground(VeyraColor.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
        .task {
            await PushNotificationRegistration.requestAuthorization()
            await syncPushToken()
            await dependencies.remoteChat?.maintainPresence()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushTokenDidChange)) { notification in
            guard let token = notification.object as? String else { return }
            Task { try? await dependencies.remoteChat?.registerPushToken(token) }
        }
    }

    private func syncPushToken() async {
        guard PushNotificationRegistration.isEnabled else { return }
        guard let token = UserDefaults.standard.string(forKey: PushNotificationRegistration.tokenKey) else { return }
        try? await dependencies.remoteChat?.registerPushToken(token)
    }

}



#Preview {
    AppRootView()
}
