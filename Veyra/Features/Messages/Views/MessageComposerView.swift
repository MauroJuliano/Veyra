import SwiftUI

struct MessageComposerView: View {
    @Binding var text: String
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: VeyraSpacing.sm) {
            TextField("Message", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, VeyraSpacing.md)
                .padding(.vertical, VeyraSpacing.sm)
                .background(VeyraColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.large))

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(canSend ? VeyraColor.accent : VeyraColor.textSecondary)
                    .clipShape(Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, VeyraSpacing.md)
        .padding(.vertical, VeyraSpacing.sm)
        .background(VeyraColor.surface)
    }
}
