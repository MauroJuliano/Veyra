import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let participantName: String

    var body: some View {
        HStack(alignment: .bottom, spacing: VeyraSpacing.sm) {
            if message.direction == .incoming {
                VeyraAvatar(name: participantName, size: .small)
            } else {
                Spacer(minLength: 64)
            }

            VStack(alignment: message.direction == .incoming ? .leading : .trailing, spacing: VeyraSpacing.xs) {
                Text(message.text)
                    .font(VeyraTypography.body)
                    .foregroundStyle(VeyraColor.textPrimary)
                    .padding(.horizontal, VeyraSpacing.md)
                    .padding(.vertical, VeyraSpacing.sm)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.medium))

                HStack(spacing: VeyraSpacing.xs) {
                    Text(message.sentAt, format: .dateTime.hour().minute())
                    if message.direction == .outgoing {
                        Image(systemName: "checkmark.done")
                            .foregroundStyle(VeyraColor.accent)
                    }
                }
                .font(VeyraTypography.caption)
                .foregroundStyle(VeyraColor.textSecondary)
                .padding(.horizontal, VeyraSpacing.sm)
            }

            if message.direction == .incoming { Spacer(minLength: 64) }
        }
        .accessibilityElement(children: .combine)
    }

    private var bubbleBackground: some ShapeStyle {
        message.direction == .outgoing
            ? AnyShapeStyle(VeyraColor.accentMuted)
            : AnyShapeStyle(VeyraColor.surfaceElevated)
    }
}

#Preview("Message bubbles") {
    VStack {
        MessageBubbleView(message: Message(text: "How are you today?", direction: .incoming), participantName: "Jessica Miller")
        MessageBubbleView(message: Message(text: "Finished work just now. And you?", direction: .outgoing), participantName: "Jessica Miller")
    }
    .padding()
    .background(VeyraColor.background)
    .preferredColorScheme(.dark)
}
