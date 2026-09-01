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

    private func validViewModel() -> RegistrationViewModel {
        let viewModel = RegistrationViewModel()
        viewModel.name = "Mauro Juliano"
        viewModel.email = "mauro@example.com"
        viewModel.password = "secret123"
        viewModel.passwordConfirmation = "secret123"
        viewModel.acceptsTerms = true
        return viewModel
    }
}
