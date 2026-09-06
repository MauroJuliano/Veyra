import Foundation
@preconcurrency import Supabase

enum RegistrationOutcome: Equatable {
    case authenticated
    case requiresEmailConfirmation(String)
}

enum AuthenticationServiceError: LocalizedError, Equatable {
    case missingConfiguration
    case usernameAlreadyInUse

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "Supabase is not configured on this device."
        case .usernameAlreadyInUse: "This username is already in use."
        }
    }
}

@MainActor
protocol AuthenticationService {
    var hasSession: Bool { get }
    func signIn(email: String, password: String) async throws
    func signUp(name: String, username: String, email: String, password: String) async throws -> RegistrationOutcome
    func signOut() async throws
}

@MainActor
final class SupabaseAuthenticationService: AuthenticationService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    var hasSession: Bool { client.auth.currentSession != nil }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func signUp(name: String, username: String, email: String, password: String) async throws -> RegistrationOutcome {
        guard try await isUsernameAvailable(client: client, username: username) else {
            throw AuthenticationServiceError.usernameAlreadyInUse
        }

        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(name), "username": .string(username)]
        )
        return response.session == nil ? .requiresEmailConfirmation(email) : .authenticated
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}

@MainActor
final class UnavailableAuthenticationService: AuthenticationService {
    var hasSession: Bool { false }
    func signIn(email: String, password: String) async throws { throw AuthenticationServiceError.missingConfiguration }
    func signUp(name: String, username: String, email: String, password: String) async throws -> RegistrationOutcome { throw AuthenticationServiceError.missingConfiguration }
    func signOut() async throws { throw AuthenticationServiceError.missingConfiguration }
}

private struct UsernameAvailability: Decodable, Sendable {
    let available: Bool
}

private func isUsernameAvailable(client: SupabaseClient, username: String) async throws -> Bool {
    let availability: UsernameAvailability = try await client
        .rpc("check_username_availability", params: ["requested_username": username])
        .single()
        .execute()
        .value
    return availability.available
}

@MainActor
enum AuthenticationServiceFactory {
    static func make(bundle: Bundle = .main) -> any AuthenticationService {
        guard let configuration = try? SupabaseConfiguration.from(bundle: bundle) else {
            return UnavailableAuthenticationService()
        }
        return SupabaseAuthenticationService(client: SupabaseClientProvider.make(configuration: configuration))
    }
}
