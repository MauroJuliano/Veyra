import Testing
@testable import Veyra

struct RegistrationViewModelTests {
    @Test func acceptsValidRegistration() {
        let viewModel = validViewModel()
        #expect(viewModel.submit())
        #expect(viewModel.validationMessage == nil)
    }

    @Test func rejectsMismatchedPasswords() {
        let viewModel = validViewModel()
        viewModel.passwordConfirmation = "different"
        #expect(!viewModel.submit())
        #expect(viewModel.validationMessage == "Passwords do not match.")
    }

    @Test func requiresTermsAcceptance() {
        let viewModel = validViewModel()
        viewModel.acceptsTerms = false
        #expect(!viewModel.submit())
        #expect(viewModel.validationMessage == "Accept the terms to continue.")
    }

    @Test func rejectsInvalidUsername() {
        let viewModel = validViewModel()
        viewModel.username = "invalid username"
        #expect(!viewModel.submit())
        #expect(viewModel.validationMessage == "Username must contain 3–30 lowercase letters, numbers, or underscores.")
    }

    @Test func normalizesUsernameAndEmail() {
        let viewModel = validViewModel()
        viewModel.username = " @Mauro_Juliano "
        viewModel.email = " Mauro@Example.com "
        #expect(viewModel.submit())
        #expect(viewModel.username == "mauro_juliano")
        #expect(viewModel.email == "mauro@example.com")
    }

    private func validViewModel() -> RegistrationViewModel {
        let viewModel = RegistrationViewModel()
        viewModel.name = "Mauro Juliano"
        viewModel.username = "mauro_juliano"
        viewModel.email = "mauro@example.com"
        viewModel.password = "secret123"
        viewModel.passwordConfirmation = "secret123"
        viewModel.acceptsTerms = true
        return viewModel
    }
}
