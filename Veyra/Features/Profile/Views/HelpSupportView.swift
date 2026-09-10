import SwiftUI

struct HelpSupportView: View {
    private let repositoryURL = URL(string: "https://github.com/MauroJuliano/Veyra")!
    private let issuesURL = URL(string: "https://github.com/MauroJuliano/Veyra/issues")!
    private let backendURL = URL(string: "https://github.com/MauroJuliano/Veyra-Supabase")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VeyraSpacing.lg) {
                introduction
                portfolioNotice
                links
                versionInformation
            }
            .padding(.horizontal, VeyraSpacing.md)
            .padding(.top, VeyraSpacing.md)
            .padding(.bottom, VeyraSpacing.xl)
        }
        .background(settingsBackground)
        .navigationTitle(Text("Help & Support", tableName: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
            Text("About Veyra", tableName: "Settings")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(VeyraColor.textPrimary)
            Text("Learn more about the project or share feedback through GitHub.", tableName: "Settings")
                .font(VeyraTypography.body)
                .foregroundStyle(VeyraColor.textSecondary)
        }
    }

    private var portfolioNotice: some View {
        HStack(alignment: .top, spacing: VeyraSpacing.md) {
            Image(systemName: "hammer.fill")
                .font(.title2)
                .foregroundStyle(VeyraColor.accent)
                .frame(width: 48, height: 48)
                .background(VeyraColor.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                Text("Portfolio project", tableName: "Settings")
                    .font(VeyraTypography.bodyEmphasized)
                Text("Veyra is an educational portfolio project, not a commercial messaging service or an official public release.", tableName: "Settings")
                    .font(VeyraTypography.caption)
                    .foregroundStyle(VeyraColor.textSecondary)
            }
        }
        .padding(VeyraSpacing.md)
        .background { GlassBackground(cornerRadius: 24, tintOpacity: 0.08, glowOpacity: 0.1) }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var links: some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.sm) {
            Text("Project links", tableName: "Settings")
                .font(VeyraTypography.bodyEmphasized)
                .foregroundStyle(VeyraColor.textSecondary)
                .padding(.leading, VeyraSpacing.xs)

            VStack(spacing: 0) {
                linkRow(title: "View iOS project", subtitle: "Source code and project documentation", icon: "swift", destination: repositoryURL)
                Divider().padding(.leading, 76).opacity(0.35)
                linkRow(title: "Report a problem", subtitle: "Open a GitHub issue with your feedback", icon: "exclamationmark.bubble", destination: issuesURL)
                Divider().padding(.leading, 76).opacity(0.35)
                linkRow(title: "View backend project", subtitle: "Supabase infrastructure and migrations", icon: "server.rack", destination: backendURL)
            }
            .background { GlassBackground(cornerRadius: 24, tintOpacity: 0.07, glowOpacity: 0.08) }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func linkRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String,
        destination: URL
    ) -> some View {
        Link(destination: destination) {
            HStack(spacing: VeyraSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(VeyraColor.accent)
                    .frame(width: 44, height: 44)
                    .background(VeyraColor.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                    Text(title, tableName: "Settings")
                        .font(VeyraTypography.bodyEmphasized)
                        .foregroundStyle(VeyraColor.textPrimary)
                    Text(subtitle, tableName: "Settings")
                        .font(VeyraTypography.caption)
                        .foregroundStyle(VeyraColor.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundStyle(VeyraColor.textSecondary)
            }
            .padding(.horizontal, VeyraSpacing.md)
            .frame(minHeight: 76)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var versionInformation: some View {
        HStack {
            Text("Version", tableName: "Settings")
                .foregroundStyle(VeyraColor.textSecondary)
            Spacer()
            Text(versionText)
                .foregroundStyle(VeyraColor.textPrimary)
        }
        .font(VeyraTypography.caption)
        .padding(.horizontal, VeyraSpacing.xs)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var settingsBackground: some View {
        ZStack {
            VeyraColor.background
            Circle()
                .fill(VeyraColor.accent.opacity(0.13))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 150, y: -280)
        }
        .ignoresSafeArea()
    }
}

#Preview("Help & Support") {
    NavigationStack { HelpSupportView() }
        .preferredColorScheme(.dark)
}
