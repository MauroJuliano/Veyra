import SwiftUI

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.direction == .outgoing { Spacer(minLength: 56) }
            VStack(alignment: .trailing, spacing: VeyraSpacing.xs) {
                Text(message.text)
                    .font(VeyraTypography.body)
                Text(message.sentAt, format: .dateTime.hour().minute())
                    .font(VeyraTypography.caption)
                    .opacity(0.72)
            }
            .foregroundStyle(message.direction == .outgoing ? Color.white : VeyraColor.textPrimary)
            .padding(.horizontal, VeyraSpacing.md)
            .padding(.vertical, VeyraSpacing.sm)
            .background(message.direction == .outgoing ? VeyraColor.accent : VeyraColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: VeyraRadius.medium))
            if message.direction == .incoming { Spacer(minLength: 56) }
        }
    }
}

#Preview("Message bubbles") {
    VStack {
        MessageBubbleView(message: Message(text: "Mensagem recebida", direction: .incoming))
        MessageBubbleView(message: Message(text: "Mensagem enviada", direction: .outgoing))
    }
    .padding()
    .background(VeyraColor.background)
}
