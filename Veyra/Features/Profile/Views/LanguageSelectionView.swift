import SwiftUI

struct LanguageSelectionView: View {
    @AppStorage(AppLanguage.storageKey) private var selectedLanguage = AppLanguage.system.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VeyraSpacing.lg) {
                introduction
                languageOptions
                restartNotice
            }
            .padding(.horizontal, VeyraSpacing.md)
            .padding(.top, VeyraSpacing.md)
            .padding(.bottom, VeyraSpacing.xl)
        }
        .background(languageBackground)
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
            Text("App language", tableName: "Language")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(VeyraColor.textPrimary)
            Text("Choose the language used throughout Veyra.", tableName: "Language")
                .font(VeyraTypography.body)
                .foregroundStyle(VeyraColor.textSecondary)
        }
    }

    private var languageOptions: some View {
        VStack(spacing: 0) {
            ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                Button { select(language) } label: {
                    languageRow(language)
                }
                .buttonStyle(.plain)

                if index < AppLanguage.allCases.count - 1 {
                    Divider()
                        .padding(.leading, 76)
                        .opacity(0.35)
                }
            }
        }
        .background { GlassBackground(cornerRadius: 24, tintOpacity: 0.07, glowOpacity: 0.08) }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        HStack(spacing: VeyraSpacing.md) {
            Text(languageIcon(language))
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(VeyraColor.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                Text(language.title)
                    .font(VeyraTypography.bodyEmphasized)
                    .foregroundStyle(VeyraColor.textPrimary)
                Text(language.subtitle)
                    .font(VeyraTypography.caption)
                    .foregroundStyle(VeyraColor.textSecondary)
            }

            Spacer()

            Image(systemName: isSelected(language) ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected(language) ? VeyraColor.accent : VeyraColor.textSecondary)
        }
        .padding(.horizontal, VeyraSpacing.md)
        .frame(minHeight: 76)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected(language) ? .isSelected : [])
    }

    private var restartNotice: some View {
        Label(
            String(localized: "Some content may update after you reopen Veyra.", table: "Language"),
            systemImage: "info.circle"
        )
            .font(VeyraTypography.caption)
            .foregroundStyle(VeyraColor.textSecondary)
            .padding(.horizontal, VeyraSpacing.xs)
    }

    private var languageBackground: some View {
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

    private func languageIcon(_ language: AppLanguage) -> String {
        switch language {
        case .system: "🌐"
        case .english: "🇬🇧"
        case .portugueseBrazil: "🇧🇷"
        }
    }

    private func isSelected(_ language: AppLanguage) -> Bool {
        selectedLanguage == language.rawValue
    }

    private func select(_ language: AppLanguage) {
        selectedLanguage = language.rawValue
        language.persistInSystemPreferences()
    }
}

#Preview {
    NavigationStack {
        LanguageSelectionView()
    }
    .preferredColorScheme(.dark)
}
