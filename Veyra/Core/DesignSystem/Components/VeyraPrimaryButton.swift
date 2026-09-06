import SwiftUI

struct VeyraPrimaryButton: View {
    let title: String
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VeyraSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }

                Text(LocalizedStringKey(title))
            }
            .font(VeyraTypography.bodyEmphasized)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .foregroundStyle(Color.white)
            .background(isEnabled ? VeyraColor.accent : VeyraColor.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

#Preview("Primary button") {
    VStack(spacing: VeyraSpacing.md) {
        VeyraPrimaryButton(title: "Continue", systemImage: "arrow.right") {}
        VeyraPrimaryButton(title: "Continue", isEnabled: false) {}
    }
    .padding()
    .background(VeyraColor.background)
}
