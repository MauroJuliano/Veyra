import SwiftUI

struct AppRootView: View {
    private let dependencies: AppDependencies
    @State private var authentication: AuthenticationCoordinator
    @State private var incomingCalls: IncomingCallCoordinator
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage = AppLanguage.system.rawValue

    init(
        dependencies: AppDependencies = AppDependencies(),
        authenticationService: any AuthenticationService = AuthenticationServiceFactory.make()
    ) {
        self.dependencies = dependencies
        _authentication = State(initialValue: AuthenticationCoordinator(service: authenticationService))
        _incomingCalls = State(initialValue: IncomingCallCoordinator(repository: dependencies.calls))
    }

    var body: some View {
        content
            .environment(\.locale, appLanguage.locale)
    }

    @ViewBuilder
    private var content: some View {
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
                    Task {
                        await authentication.signUp(
                            name: name,
                            username: username,
                            email: email,
                            password: password,
                            onRegistrationSucceeded: dependencies.clearLocalData
                        )
                    }
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

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: selectedLanguage) ?? .system
    }

    private var authenticatedContent: some View {
        TabView {
            NavigationStack {
                ConversationListView(
                    viewModel: ConversationListViewModel(repository: dependencies.conversations, remoteRepository: dependencies.remoteChat),
                    messageCache: dependencies.messageCache,
                    callRepository: dependencies.calls
                )
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case let .conversation(conversation):
                        MessageTimelineView(
                            conversation: conversation,
                            repository: dependencies.remoteChat,
                            callRepository: dependencies.calls,
                            cache: dependencies.messageCache
                        )
                    }
                }
            }
            .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }

            NavigationStack {
                ContactListView(
                    repository: dependencies.remoteChat,
                    callRepository: dependencies.calls,
                    localRepository: dependencies.contacts,
                    messageCache: dependencies.messageCache
                )
            }
                .tabItem { Label("Connections", systemImage: "person.2.fill") }

            ProfileView(viewModel: ProfileViewModel(store: dependencies.profileStore, remoteRepository: dependencies.remoteChat), onLogout: {
                Task {
                    if let token = UserDefaults.standard.string(forKey: PushNotificationRegistration.tokenKey) {
                        try? await dependencies.remoteChat?.unregisterPushToken(token)
                    }
                    await authentication.signOut()
                    if authentication.route == .login {
                        dependencies.clearLocalData()
                    }
                }
            })
                .tabItem { Label("You", systemImage: "person.crop.circle.fill") }
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
        .task { await incomingCalls.observe() }
        .fullScreenCover(item: $incomingCalls.incomingCall) { call in
            VoiceCallView(call: call, repository: dependencies.calls)
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
