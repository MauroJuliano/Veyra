import SwiftUI

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    let isLoading: Bool
    let externalError: String?
    let onAuthenticated: (String, String) -> Void
    let onCreateAccount: () -> Void

    init(viewModel: LoginViewModel = LoginViewModel(), isLoading: Bool = false, externalError: String? = nil, onAuthenticated: @escaping (String, String) -> Void, onCreateAccount: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        self.isLoading = isLoading
        self.externalError = externalError
        self.onAuthenticated = onAuthenticated
        self.onCreateAccount = onCreateAccount
    }

    var body: some View {
        ZStack {
            loginBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: VeyraSpacing.lg) {
                    header
                    loginCard
                    Button(action: onCreateAccount) {
                        HStack {
                            Text("New here?").foregroundStyle(VeyraColor.textSecondary)
                            Text("Create an account").foregroundStyle(VeyraColor.accent).fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .padding(.horizontal, VeyraSpacing.lg)
                        .frame(height: 68)
                        .background { GlassBackground(cornerRadius: 22, tintOpacity: 0.08, glowOpacity: 0.1) }
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    footer
                }
                .padding(.horizontal, VeyraSpacing.lg)
                .padding(.top, 56)
                .padding(.bottom, VeyraSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: VeyraSpacing.sm) {
            Image(systemName: "message.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.pink, VeyraColor.accent, .white], startPoint: .bottomLeading, endPoint: .topTrailing)
                )
                .shadow(color: VeyraColor.accent.opacity(0.8), radius: 22)

            Text(AppMetadata.name)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, VeyraColor.accent, .pink], startPoint: .leading, endPoint: .trailing)
                )

            Text("Connect. Share. Belong.")
                .font(VeyraTypography.body)
                .foregroundStyle(VeyraColor.textSecondary)
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.lg) {
            VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                Text("Welcome back")
                    .font(VeyraTypography.title)
                Text("Login to continue your conversations")
                    .font(VeyraTypography.body)
                    .foregroundStyle(VeyraColor.textSecondary)
            }

            loginField(title: "Email", icon: "envelope", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)

            passwordField

            if let message = viewModel.validationMessage ?? externalError {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(VeyraTypography.caption)
                    .foregroundStyle(VeyraColor.danger)
            }

            Button {
                if viewModel.submit() { onAuthenticated(viewModel.email, viewModel.password) }
            } label: {
                HStack {
                    Spacer()
                    if isLoading { ProgressView().tint(.white) } else { Text("Login").font(VeyraTypography.bodyEmphasized) }
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .padding(.horizontal, VeyraSpacing.md)
                .frame(height: 56)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(colors: [.pink, VeyraColor.accent], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: VeyraColor.accent.opacity(0.4), radius: 18, y: 8)
            }
            .disabled(!viewModel.canSubmit || isLoading)
            .opacity(viewModel.canSubmit && !isLoading ? 1 : 0.55)
        }
        .padding(VeyraSpacing.lg)
        .background { GlassBackground(cornerRadius: 28, tintOpacity: 0.1, glowOpacity: 0.22) }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func loginField(title: String, icon: String, text: Binding<String>) -> some View {
        HStack(spacing: VeyraSpacing.md) {
            Image(systemName: icon).foregroundStyle(VeyraColor.accent)
            VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                Text(title).font(VeyraTypography.caption).foregroundStyle(VeyraColor.textSecondary)
                TextField("you@example.com", text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, VeyraSpacing.md)
        .frame(height: 70)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1)) }
    }

    private var passwordField: some View {
        HStack(spacing: VeyraSpacing.md) {
            Image(systemName: "lock").foregroundStyle(VeyraColor.accent)
            VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                Text("Password").font(VeyraTypography.caption).foregroundStyle(VeyraColor.textSecondary)
                Group {
                    if viewModel.showsPassword {
                        TextField("Password", text: $viewModel.password)
                    } else {
                        SecureField("Password", text: $viewModel.password)
                    }
                }
                .textContentType(.password)
            }
            Spacer()
            Button { viewModel.showsPassword.toggle() } label: {
                Image(systemName: viewModel.showsPassword ? "eye.slash" : "eye")
            }
            .foregroundStyle(VeyraColor.textSecondary)
            .accessibilityLabel(Text(viewModel.showsPassword ? "Hide password" : "Show password"))
        }
        .padding(.horizontal, VeyraSpacing.md)
        .frame(height: 70)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1)) }
    }

    private var footer: some View {
        Text("Authentication powered by Supabase.")
            .font(VeyraTypography.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(VeyraColor.textSecondary)
    }

    private var loginBackground: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.02, blue: 0.10), Color(red: 0.12, green: 0.03, blue: 0.18), Color(red: 0.03, green: 0.02, blue: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Color.purple.opacity(0.22)).frame(width: 360).blur(radius: 100).offset(x: -120, y: -250)
            Circle().fill(Color.pink.opacity(0.16)).frame(width: 300).blur(radius: 110).offset(x: 160, y: -40)
        }
        .ignoresSafeArea()
    }
}

#Preview("Login") {
    LoginView(onAuthenticated: { _, _ in })
}
