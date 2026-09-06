import Foundation
import Observation

@Observable
final class RegistrationViewModel {
    var name = ""
    var username = ""
    var email = ""
    var password = ""
    var passwordConfirmation = ""
    var acceptsTerms = false
    private(set) var validationMessage: String?

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
            && !passwordConfirmation.isEmpty
            && acceptsTerms
    }

    func submit() -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedName.count >= 2 else {
            validationMessage = String(localized: "Enter your full name.")
            return false
        }
        guard normalizedUsername.range(of: "^[a-z0-9_]{3,30}$", options: .regularExpression) != nil else {
            validationMessage = String(localized: "Username must contain 3–30 lowercase letters, numbers, or underscores.")
            return false
        }
        guard normalizedEmail.range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) != nil else {
            validationMessage = String(localized: "Enter a valid email address.")
            return false
        }
        guard password.count >= 6 else {
            validationMessage = String(localized: "Password must contain at least 6 characters.")
            return false
        }
        guard password == passwordConfirmation else {
            validationMessage = String(localized: "Passwords do not match.")
            return false
        }
        guard acceptsTerms else {
            validationMessage = String(localized: "Accept the terms to continue.")
            return false
        }
        name = normalizedName
        username = normalizedUsername
        email = normalizedEmail
        validationMessage = nil
        return true
    }
}
