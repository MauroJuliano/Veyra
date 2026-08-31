import SwiftUI

struct DesignSystemCatalogView: View {
    @State private var displayName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VeyraSpacing.xl) {
                typographySection
                colorSection
                componentSection
            }
            .padding(VeyraSpacing.lg)
        }
        .background(VeyraColor.background)
    }

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.sm) {
            Text("Veyra")
                .font(VeyraTypography.display)
            Text("Conversations that feel close.")
                .font(VeyraTypography.title)
            Text("A calm foundation for every conversation.")
                .font(VeyraTypography.body)
                .foregroundStyle(VeyraColor.textSecondary)
        }
        .foregroundStyle(VeyraColor.textPrimary)
    }

    private var colorSection: some View {
        HStack(spacing: VeyraSpacing.sm) {
            colorSwatch(VeyraColor.accent)
            colorSwatch(VeyraColor.accentMuted)
            colorSwatch(VeyraColor.success)
            colorSwatch(VeyraColor.danger)
        }
    }

    private var componentSection: some View {
        VStack(spacing: VeyraSpacing.lg) {
            HStack(spacing: VeyraSpacing.md) {
                VeyraAvatar(name: "Mauro Figueiredo", size: .large)

                VStack(alignment: .leading, spacing: VeyraSpacing.xxs) {
                    Text("Mauro Figueiredo")
                        .font(VeyraTypography.bodyEmphasized)
                    Text("Available")
                        .font(VeyraTypography.caption)
                        .foregroundStyle(VeyraColor.success)
                }

                Spacer()
            }

            VeyraTextField(
                title: "Display name",
                placeholder: "How should people call you?",
                text: $displayName
            )

            VeyraPrimaryButton(title: "Continue", systemImage: "arrow.right") {}
        }
        .padding(VeyraSpacing.lg)
        .background(VeyraColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.large, style: .continuous))
        .foregroundStyle(VeyraColor.textPrimary)
    }

    private func colorSwatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: VeyraRadius.small, style: .continuous)
            .fill(color)
            .frame(height: 56)
    }
}

#Preview("Light") {
    DesignSystemCatalogView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    DesignSystemCatalogView()
        .preferredColorScheme(.dark)
}
