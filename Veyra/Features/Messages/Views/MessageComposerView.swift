import SwiftUI
import PhotosUI

struct MessageComposerView: View {
    @Binding var text: String
    let canSend: Bool
    let onSend: () -> Void
    @Binding var selectedPhoto: PhotosPickerItem?
    let audioRecorder: AudioMessageRecorder
    let onSendAudio: (AudioMessageRecorder.Recording) -> Void
    let isReplying: Bool
    @FocusState private var isTextFieldFocused: Bool

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
                if audioRecorder.isRecording {
                    Circle().fill(VeyraColor.danger).frame(width: 8, height: 8)
                    Text(recordingDuration)
                        .monospacedDigit()
                        .foregroundStyle(VeyraColor.textPrimary)
                    Spacer()
                    Button("Cancel") { audioRecorder.cancel() }
                        .foregroundStyle(VeyraColor.danger)
                    Button(action: finishRecording) { Image(systemName: "stop.fill") }
                        .accessibilityLabel("Finish recording")
                } else {
                    TextField("Message...", text: $text, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($isTextFieldFocused)
                    Button { Task { await audioRecorder.start() } } label: { Image(systemName: "mic") }
                        .accessibilityLabel("Record audio")
                }
            }
            .foregroundStyle(VeyraColor.textSecondary)
            .padding(.horizontal, VeyraSpacing.md)
            .padding(.vertical, 10)
            .background { GlassBackground(tintOpacity: 0.1, glowOpacity: 0.1) }
            .clipShape(RoundedRectangle(cornerRadius: 18))

            if !audioRecorder.isRecording {
                composerButton(systemImage: "paperplane.fill", label: "Send message", action: onSend)
                    .disabled(!canSend)
                    .opacity(canSend ? 1 : 0.45)
            }
        }
        .padding(.horizontal, VeyraSpacing.md)
        .padding(.vertical, VeyraSpacing.sm)
        .background(VeyraColor.surface.opacity(0.96))
        .onChange(of: isReplying) { _, replying in
            if replying { isTextFieldFocused = true }
        }
    }

    private var recordingDuration: String {
        let seconds = Int(audioRecorder.duration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func finishRecording() {
        do { onSendAudio(try audioRecorder.finish()) } catch { audioRecorder.cancel() }
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
