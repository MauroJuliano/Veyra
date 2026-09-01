import SwiftUI

struct EmailConfirmationView: View {
    let email: String
    let onBack: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.02, blue: 0.10), Color(red: 0.12, green: 0.03, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: VeyraSpacing.lg) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 52))
                    .foregroundStyle(VeyraColor.accent)
                    .shadow(color: VeyraColor.accent.opacity(0.7), radius: 20)
                Text("Check your email")
                    .font(VeyraTypography.title)
                Text("We sent a confirmation link to\n\(email)")
                    .font(VeyraTypography.body)
                    .foregroundStyle(VeyraColor.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Back to login", action: onBack)
                    .font(VeyraTypography.bodyEmphasized)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(colors: [.pink, VeyraColor.accent], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(VeyraSpacing.xl)
            .background { GlassBackground(cornerRadius: 28, tintOpacity: 0.1, glowOpacity: 0.22) }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(VeyraSpacing.lg)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    EmailConfirmationView(email: "hello@veyra.app", onBack: {})
}
