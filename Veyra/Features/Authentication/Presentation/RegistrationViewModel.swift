import Foundation
import Observation

@Observable
final class RegistrationViewModel {
    var name = ""
    var email = ""
    var password = ""
    var passwordConfirmation = ""
    var acceptsTerms = false
    private(set) var validationMessage: String?

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
            && !passwordConfirmation.isEmpty
            && acceptsTerms
    }

    func submit() -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.count >= 2 else {
            validationMessage = "Enter your full name."
            return false
        }
        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            validationMessage = "Enter a valid email address."
            return false
        }
        guard password.count >= 6 else {
            validationMessage = "Password must contain at least 6 characters."
            return false
        }
        guard password == passwordConfirmation else {
            validationMessage = "Passwords do not match."
            return false
        }
        guard acceptsTerms else {
            validationMessage = "Accept the terms to continue."
            return false
        }
        name = normalizedName
        email = normalizedEmail
        validationMessage = nil
        return true
    }
}
