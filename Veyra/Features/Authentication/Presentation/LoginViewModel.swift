import Foundation
import Observation

@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var showsPassword = false
    private(set) var validationMessage: String?

    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    func submit() -> Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
            validationMessage = String(localized: "Enter a valid email address.")
            return false
        }
        guard password.count >= 6 else {
            validationMessage = String(localized: "Password must contain at least 6 characters.")
            return false
        }
        email = normalizedEmail
        validationMessage = nil
        return true
    }
}
