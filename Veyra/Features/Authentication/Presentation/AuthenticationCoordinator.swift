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
        await perform(context: .authentication) {
            try await service.signIn(email: email, password: password)
            route = .authenticated
        }
    }

    func signUp(
        name: String,
        username: String,
        email: String,
        password: String,
        onRegistrationSucceeded: () -> Void = {}
    ) async {
        await perform(context: .registration) {
            let outcome = try await service.signUp(
                name: name,
                username: username,
                email: email,
                password: password
            )
            onRegistrationSucceeded()
            switch outcome {
            case .authenticated: route = .authenticated
            case .requiresEmailConfirmation(let email): route = .emailConfirmation(email)
            }
        }
    }

    func signOut() async {
        await perform(context: .authentication) {
            try await service.signOut()
            route = .login
        }
    }

    private func perform(
        context: UserFacingErrorContext,
        _ operation: () async throws -> Void
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { try await operation() } catch {
            errorMessage = UserFacingError.message(for: error, context: context)
        }
    }
}
