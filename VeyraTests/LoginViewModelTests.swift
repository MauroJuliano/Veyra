import Testing
@testable import Veyra

struct LoginViewModelTests {
    @Test func acceptsValidCredentialsAndNormalizesEmail() {
        let viewModel = LoginViewModel()
        viewModel.email = "  mauro@example.com  "
        viewModel.password = "secret123"

        #expect(viewModel.submit())
        #expect(viewModel.email == "mauro@example.com")
        #expect(viewModel.validationMessage == nil)
    }

    @Test func rejectsInvalidEmail() {
        let viewModel = LoginViewModel()
        viewModel.email = "mauro"
        viewModel.password = "secret123"

        #expect(!viewModel.submit())
        #expect(viewModel.validationMessage == "Enter a valid email address.")
    }

    @Test func rejectsShortPassword() {
        let viewModel = LoginViewModel()
        viewModel.email = "mauro@example.com"
        viewModel.password = "12345"

        #expect(!viewModel.submit())
        #expect(viewModel.validationMessage == "Password must contain at least 6 characters.")
    }
}
