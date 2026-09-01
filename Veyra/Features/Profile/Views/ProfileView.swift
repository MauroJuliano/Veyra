import SwiftUI

struct ProfileView: View {
    let onLogout: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: VeyraSpacing.lg) {
                VeyraAvatar(name: "Veyra Member", size: .large, showsOnlineIndicator: true)

                VStack(spacing: VeyraSpacing.xs) {
                    Text("Veyra Member").font(VeyraTypography.title)
                    Text("Local preview account")
                        .font(VeyraTypography.body)
                        .foregroundStyle(VeyraColor.textSecondary)
                }

                Button(role: .destructive, action: onLogout) {
                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(VeyraTypography.bodyEmphasized)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.bordered)
                .tint(VeyraColor.danger)
                .padding(.top, VeyraSpacing.md)
            }
            .padding(VeyraSpacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                LinearGradient(colors: [VeyraColor.accentMuted.opacity(0.55), VeyraColor.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView(onLogout: {})
        .preferredColorScheme(.dark)
}
