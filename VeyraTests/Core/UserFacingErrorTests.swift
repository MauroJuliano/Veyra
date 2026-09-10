import Foundation
import Testing
@testable import Veyra

struct UserFacingErrorTests {
    @Test
    func mapsConnectivityFailuresWithoutExposingTechnicalDetails() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )

        let message = UserFacingError.message(for: error, context: .messages)

        #expect(message == AppLocalization.string("Check your internet connection and try again.", table: "Errors"))
        #expect(!message.localizedCaseInsensitiveContains("NSURLError"))
    }

    @Test
    func mapsAuthenticationServerTextToAStableMessage() {
        let error = NSError(
            domain: "Supabase.Auth",
            code: 400,
            userInfo: [NSLocalizedDescriptionKey: "Invalid login credentials"]
        )

        let message = UserFacingError.message(for: error, context: .authentication)

        #expect(message == AppLocalization.string("The email or password is incorrect.", table: "Errors"))
    }

    @Test
    func usesTheActionContextForUnknownFailures() {
        let error = NSError(
            domain: "ExampleBackend",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "relation public.internal_table does not exist"]
        )

        let message = UserFacingError.message(for: error, context: .deleteMessage)

        #expect(message == AppLocalization.string("Unable to remove this message. Please try again.", table: "Errors"))
        #expect(!message.contains("internal_table"))
    }

    @Test
    func usesRegistrationMessageWhenAccountCreationFails() {
        let error = NSError(
            domain: "Supabase.Auth",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected backend response"]
        )

        let message = UserFacingError.message(for: error, context: .registration)

        #expect(message == AppLocalization.string("We couldn't create your account. Please try again.", table: "Errors"))
    }

    @Test
    func mapsDuplicateRegistrationEmail() {
        let error = NSError(
            domain: "Supabase.Auth",
            code: 422,
            userInfo: [NSLocalizedDescriptionKey: "User already registered"]
        )

        let message = UserFacingError.message(for: error, context: .registration)

        #expect(message == AppLocalization.string("This email is already in use.", table: "Errors"))
    }
}
