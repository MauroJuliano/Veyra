import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let participantName: String
    var onImageTap: (URL) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .bottom, spacing: VeyraSpacing.sm) {
            if message.direction == .incoming {
                VeyraAvatar(name: participantName, size: .small)
            } else {
                Spacer(minLength: 64)
            }

            VStack(alignment: message.direction == .incoming ? .leading : .trailing, spacing: VeyraSpacing.xs) {
                Group {
                    if let imageURL = message.imageURL {
                        Button { onImageTap(imageURL) } label: {
                            AsyncImage(url: imageURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 220, height: 220)
                            .clipped()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open image")
                    } else if message.isSticker {
                        Text(message.text)
                            .font(.system(size: 64))
                    } else {
                        Text(message.text)
                            .padding(.horizontal, VeyraSpacing.md)
                            .padding(.vertical, VeyraSpacing.sm)
                    }
                }
                    .font(VeyraTypography.body)
                    .foregroundStyle(VeyraColor.textPrimary)
                    .background {
                        if !message.isSticker {
                            GlassBackground(
                                tintOpacity: message.direction == .outgoing ? 0.2 : 0.08,
                                glowOpacity: message.direction == .outgoing ? 0.2 : 0.08
                            )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack(spacing: VeyraSpacing.xs) {
                    Text(message.sentAt, format: .dateTime.hour().minute())
                    if message.direction == .outgoing {
                        MessageReceiptIcon(isRead: message.receipt == .read)
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

}

struct MessageReceiptIcon: View {
    let isRead: Bool

    var body: some View {
        Group {
            if isRead {
                HStack(spacing: -5) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .foregroundStyle(VeyraColor.accent)
            } else {
                Image(systemName: "checkmark")
                    .foregroundStyle(VeyraColor.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRead ? "Read" : "Sent")
    }
}

#Preview("Message bubbles") {
    VStack {
        MessageBubbleView(message: Message(text: "How are you today?", direction: .incoming), participantName: "Jessica Miller")
        MessageBubbleView(message: Message(text: "Finished work just now. And you?", direction: .outgoing), participantName: "Jessica Miller")
        MessageBubbleView(message: Message(text: "This one was read.", direction: .outgoing, receipt: .read), participantName: "Jessica Miller")
    }
    .padding()
    .background(VeyraColor.background)
    .preferredColorScheme(.dark)
}
