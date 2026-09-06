import SwiftUI

struct VeyraTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
            Text(LocalizedStringKey(title))
                .font(VeyraTypography.caption)
                .foregroundStyle(VeyraColor.textSecondary)

            TextField(LocalizedStringKey(placeholder), text: $text)
                .font(VeyraTypography.body)
                .foregroundStyle(VeyraColor.textPrimary)
                .padding(.horizontal, VeyraSpacing.md)
                .frame(minHeight: 52)
                .background(VeyraColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: VeyraRadius.medium, style: .continuous)
                        .stroke(VeyraColor.divider, lineWidth: 1)
                }
        }
    }
}

#Preview("Text field") {
    @Previewable @State var name = ""

    VeyraTextField(title: "Display name", placeholder: "How should people call you?", text: $name)
        .padding()
        .background(VeyraColor.background)
}
