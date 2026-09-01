import SwiftUI
import PhotosUI

struct MessageComposerView: View {
    @Binding var text: String
    let canSend: Bool
    let onSend: () -> Void
    @Binding var selectedPhoto: PhotosPickerItem?

    var body: some View {
        HStack(alignment: .bottom, spacing: VeyraSpacing.sm) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(VeyraColor.accent)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Add photo")

            HStack(alignment: .bottom, spacing: VeyraSpacing.sm) {
                TextField("Message...", text: $text, axis: .vertical)
                    .lineLimit(1...5)
                Button(action: {}) { Image(systemName: "mic") }
                    .accessibilityLabel("Record audio")
                Button(action: {}) { Image(systemName: "face.smiling") }
                    .accessibilityLabel("Choose emoji")
            }
            .foregroundStyle(VeyraColor.textSecondary)
            .padding(.horizontal, VeyraSpacing.md)
            .padding(.vertical, 10)
            .background { GlassBackground(tintOpacity: 0.1, glowOpacity: 0.1) }
            .clipShape(RoundedRectangle(cornerRadius: 18))

            composerButton(systemImage: "paperplane.fill", label: "Send message", action: onSend)
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.45)
        }
        .padding(.horizontal, VeyraSpacing.md)
        .padding(.vertical, VeyraSpacing.sm)
        .background(VeyraColor.surface.opacity(0.96))
    }

    private func composerButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(VeyraColor.accent)
                .clipShape(Circle())
        }
        .accessibilityLabel(label)
    }
}
