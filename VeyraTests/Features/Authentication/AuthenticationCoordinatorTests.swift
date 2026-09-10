import Testing
@testable import Veyra

@MainActor
struct AuthenticationCoordinatorTests {
    @Test func startsAuthenticatedWhenServiceHasSession() {
        let coordinator = AuthenticationCoordinator(service: AuthenticationServiceSpy(hasSession: true))
        #expect(coordinator.route == .authenticated)
    }

    @Test func signsInAndRoutesToApp() async {
        let coordinator = AuthenticationCoordinator(service: AuthenticationServiceSpy())
        await coordinator.signIn(email: "user@veyra.app", password: "password")
        #expect(coordinator.route == .authenticated)
        #expect(coordinator.errorMessage == nil)
    }

    @Test func registrationCanRequireEmailConfirmation() async {
        let service = AuthenticationServiceSpy(registrationOutcome: .requiresEmailConfirmation("user@veyra.app"))
        let coordinator = AuthenticationCoordinator(service: service)
        await coordinator.signUp(name: "User", username: "user", email: "user@veyra.app", password: "password")
        #expect(coordinator.route == .emailConfirmation("user@veyra.app"))
    }

    @Test func clearsPreviousSessionBeforeShowingTheNewAccount() async {
        let coordinator = AuthenticationCoordinator(service: AuthenticationServiceSpy())
        coordinator.showRegistration()
        var routeWhenCleanupRan: AuthenticationCoordinator.Route?

        await coordinator.signUp(
            name: "New user",
            username: "new.user",
            email: "new@veyra.app",
            password: "password",
            onRegistrationSucceeded: { routeWhenCleanupRan = coordinator.route }
        )

        #expect(routeWhenCleanupRan == .registration)
        #expect(coordinator.route == .authenticated)
    }

    @Test func keepsLocalDataWhenRegistrationFails() async {
        let coordinator = AuthenticationCoordinator(service: AuthenticationServiceSpy(error: TestError.failed))
        var cleanupRan = false

        await coordinator.signUp(
            name: "New user",
            username: "new.user",
            email: "new@veyra.app",
            password: "password",
            onRegistrationSucceeded: { cleanupRan = true }
        )

        #expect(!cleanupRan)
        #expect(coordinator.route == .login)
    }

    @Test func exposesAuthenticationErrors() async {
        let coordinator = AuthenticationCoordinator(service: AuthenticationServiceSpy(error: TestError.failed))
        await coordinator.signIn(email: "user@veyra.app", password: "password")
        #expect(coordinator.route == .login)
        #expect(coordinator.errorMessage != nil)
    }
}

private enum TestError: Error { case failed }

@MainActor
private final class AuthenticationServiceSpy: AuthenticationService {
    let hasSession: Bool
    let registrationOutcome: RegistrationOutcome
    let error: Error?

    init(hasSession: Bool = false, registrationOutcome: RegistrationOutcome = .authenticated, error: Error? = nil) {
        self.hasSession = hasSession
        self.registrationOutcome = registrationOutcome
        self.error = error
    }

    func signIn(email: String, password: String) async throws { if let error { throw error } }
    func signUp(name: String, username: String, email: String, password: String) async throws -> RegistrationOutcome {
        if let error { throw error }
        return registrationOutcome
    }
    func signOut() async throws { if let error { throw error } }
}
