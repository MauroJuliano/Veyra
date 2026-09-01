import Observation

@MainActor
@Observable
final class AuthenticationCoordinator {
    enum Route: Equatable {
        case login
        case registration
        case authenticated
        case emailConfirmation(String)
    }

    private let service: any AuthenticationService
    var route: Route
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(service: any AuthenticationService) {
        self.service = service
        route = service.hasSession ? .authenticated : .login
    }

    func showLogin() { route = .login; errorMessage = nil }
    func showRegistration() { route = .registration; errorMessage = nil }

    func signIn(email: String, password: String) async {
        await perform {
            try await service.signIn(email: email, password: password)
            route = .authenticated
        }
    }

    func signUp(name: String, email: String, password: String) async {
        await perform {
            switch try await service.signUp(name: name, email: email, password: password) {
            case .authenticated: route = .authenticated
            case .requiresEmailConfirmation(let email): route = .emailConfirmation(email)
            }
        }
    }

    func signOut() async {
        await perform {
            try await service.signOut()
            route = .login
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { try await operation() } catch { errorMessage = error.localizedDescription }
    }
}
