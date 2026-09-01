import SwiftUI

struct AppRootView: View {
    private enum AuthenticationRoute: Equatable {
        case login
        case registration
        case authenticated
    }

    private let dependencies: AppDependencies
    @State private var authenticationRoute = AuthenticationRoute.login

    init(dependencies: AppDependencies = AppDependencies()) {
        self.dependencies = dependencies
    }

    var body: some View {
        if authenticationRoute == .authenticated {
            authenticatedContent
                .transition(.opacity)
        } else if authenticationRoute == .registration {
            RegistrationView(
                onBack: { withAnimation(.easeInOut) { authenticationRoute = .login } },
                onRegistered: { withAnimation(.easeInOut) { authenticationRoute = .authenticated } }
            )
            .transition(.opacity)
        } else {
            LoginView(
                onAuthenticated: { withAnimation(.easeInOut) { authenticationRoute = .authenticated } },
                onCreateAccount: { withAnimation(.easeInOut) { authenticationRoute = .registration } }
            )
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

            PlaceholderTabView(title: "Profile", message: "Profile customization arrives soon.", systemImage: "person.crop.circle")
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
