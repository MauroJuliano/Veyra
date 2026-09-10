import SwiftUI

struct RegistrationView: View {
    @State private var viewModel: RegistrationViewModel
    let isLoading: Bool
    let externalError: String?
    let onBack: () -> Void
    let onRegistered: (String, String, String, String) -> Void

    init(viewModel: RegistrationViewModel = RegistrationViewModel(), isLoading: Bool = false, externalError: String? = nil, onBack: @escaping () -> Void, onRegistered: @escaping (String, String, String, String) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.isLoading = isLoading
        self.externalError = externalError
        self.onBack = onBack
        self.onRegistered = onRegistered
    }

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: VeyraSpacing.lg) {
                    HStack {
                        Button(action: onBack) { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Back to login")
                        Spacer()
                        Text(AppMetadata.name).font(VeyraTypography.title)
                        Spacer()
                        Color.clear.frame(width: 16)
                    }

                    VStack(alignment: .leading, spacing: VeyraSpacing.lg) {
                        VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                            Text("Create your account").font(VeyraTypography.title)
                            Text("Join your conversations in a few steps.")
                                .foregroundStyle(VeyraColor.textSecondary)
                        }

                        field("Full name", icon: "person", text: $viewModel.name, contentType: .name)
                        field("Username", icon: "at", text: $viewModel.username, contentType: .username)
                        field("Email", icon: "envelope", text: $viewModel.email, contentType: .emailAddress)
                        secureField("Password", text: $viewModel.password, contentType: .newPassword)
                        secureField("Confirm password", text: $viewModel.passwordConfirmation, contentType: .newPassword)

                        Button { viewModel.acceptsTerms.toggle() } label: {
                            Label("I agree to the Terms and Privacy Policy", systemImage: viewModel.acceptsTerms ? "checkmark.circle.fill" : "circle")
                                .font(VeyraTypography.caption)
                        }
                        .foregroundStyle(viewModel.acceptsTerms ? VeyraColor.accent : VeyraColor.textSecondary)

                        if let message = viewModel.validationMessage ?? externalError {
                            Label(message, systemImage: "exclamationmark.circle")
                                .font(VeyraTypography.caption)
                                .foregroundStyle(VeyraColor.danger)
                        }

                        Button {
                            if viewModel.submit() { onRegistered(viewModel.name, viewModel.username, viewModel.email, viewModel.password) }
                        } label: {
                            HStack {
                                Spacer()
                                if isLoading { ProgressView().tint(.white) } else { Text("Create account").font(VeyraTypography.bodyEmphasized) }
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .padding(.horizontal, VeyraSpacing.md)
                            .frame(height: 56)
                            .foregroundStyle(.white)
                            .background(LinearGradient(colors: [.pink, VeyraColor.accent], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: VeyraColor.accent.opacity(0.4), radius: 18, y: 8)
                        }
                        .disabled(!viewModel.canSubmit || isLoading)
                        .opacity(viewModel.canSubmit && !isLoading ? 1 : 0.55)
                    }
                    .padding(VeyraSpacing.lg)
                    .background { GlassBackground(cornerRadius: 28, tintOpacity: 0.1, glowOpacity: 0.22) }
                    .clipShape(RoundedRectangle(cornerRadius: 28))

                    Text("Your account is securely created with Supabase.")
                        .font(VeyraTypography.caption)
                        .foregroundStyle(VeyraColor.textSecondary)
                }
                .padding(.horizontal, VeyraSpacing.lg)
                .padding(.vertical, VeyraSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .preferredColorScheme(.dark)
    }

    private func field(_ title: String, icon: String, text: Binding<String>, contentType: UITextContentType) -> some View {
        HStack(spacing: VeyraSpacing.md) {
            Image(systemName: icon).foregroundStyle(VeyraColor.accent)
            TextField(LocalizedStringKey(title), text: text)
                .textContentType(contentType)
                .textInputAutocapitalization(contentType == .emailAddress || contentType == .username ? .never : .words)
                .autocorrectionDisabled(contentType == .emailAddress || contentType == .username)
        }
        .padding(.horizontal, VeyraSpacing.md)
        .frame(height: 64)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1)) }
    }

    private func secureField(_ title: String, text: Binding<String>, contentType: UITextContentType) -> some View {
        HStack(spacing: VeyraSpacing.md) {
            Image(systemName: "lock").foregroundStyle(VeyraColor.accent)
            SecureField(LocalizedStringKey(title), text: text).textContentType(contentType)
        }
        .padding(.horizontal, VeyraSpacing.md)
        .frame(height: 64)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1)) }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.02, blue: 0.10), Color(red: 0.12, green: 0.03, blue: 0.18), Color(red: 0.03, green: 0.02, blue: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color.purple.opacity(0.22)).frame(width: 360).blur(radius: 100).offset(x: -120, y: -250)
            Circle().fill(Color.pink.opacity(0.16)).frame(width: 300).blur(radius: 110).offset(x: 160, y: 120)
        }
        .ignoresSafeArea()
    }
}

#Preview("Registration") {
    RegistrationView(onBack: {}, onRegistered: { _, _, _, _ in })
}
