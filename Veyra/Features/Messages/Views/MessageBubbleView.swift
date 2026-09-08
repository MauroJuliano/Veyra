import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let participantName: String
    var participantAvatarURL: URL? = nil
    var onReply: () -> Void = {}
    var onImageTap: (URL) -> Void = { _ in }
    var onRetry: () -> Void = {}
    @State private var replyDragOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: VeyraSpacing.sm) {
            if message.direction == .incoming {
                VeyraAvatar(name: participantName, imageURL: participantAvatarURL, size: .small)
            } else {
                Spacer(minLength: 64)
            }

            VStack(alignment: message.direction == .incoming ? .leading : .trailing, spacing: VeyraSpacing.xs) {
                if let reply = message.replyPreview {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reply.isOwnMessage ? String(localized: "You") : participantName)
                            .font(VeyraTypography.caption)
                            .foregroundStyle(VeyraColor.accent)
                        Text(reply.text)
                            .font(VeyraTypography.caption)
                            .lineLimit(2)
                            .foregroundStyle(VeyraColor.textSecondary)
                    }
                    .padding(VeyraSpacing.sm)
                    .frame(maxWidth: 220, alignment: .leading)
                    .background(VeyraColor.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Group {
                    if let audioURL = message.audioURL {
                        AudioMessagePlayerView(
                            url: audioURL,
                            duration: message.audioDuration ?? 0,
                            avatarName: message.direction == .incoming ? participantName : nil,
                            avatarURL: message.direction == .incoming ? participantAvatarURL : nil,
                            avatarSize: .medium,
                            direction: message.direction
                        )
                    } else if let imageURL = message.imageURL {
                        Button { onImageTap(imageURL) } label: {
                            VeyraCachedImage(url: imageURL) { image in
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
                        if message.deliveryState == .failed {
                            Button(action: onRetry) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundStyle(VeyraColor.danger)
                            }
                            .accessibilityLabel("Retry sending")
                        } else if message.deliveryState == .sending {
                            ProgressView().controlSize(.mini)
                        } else {
                            MessageReceiptIcon(isRead: message.receipt == .read)
                        }
                    }
                }
                .font(VeyraTypography.caption)
                .foregroundStyle(VeyraColor.textSecondary)
                .padding(.horizontal, VeyraSpacing.sm)

                if !message.reactions.isEmpty {
                    HStack(spacing: VeyraSpacing.xs) {
                        ForEach(message.reactions) { reaction in
                            Text("\(reaction.emoji) \(reaction.count)")
                                .font(VeyraTypography.caption)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.82))
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule().stroke(
                                        reaction.isSelectedByCurrentUser ? VeyraColor.accent : Color.white.opacity(0.14),
                                        lineWidth: 1
                                    )
                                }
                        }
                    }
                    .offset(y: -3)
                }
            }

            if message.direction == .incoming { Spacer(minLength: 64) }
        }
        .background(alignment: .leading) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.title3)
                .foregroundStyle(VeyraColor.accent)
                .frame(width: 44, height: 44)
                .opacity(min(replyDragOffset / 44, 1))
                .scaleEffect(0.75 + min(replyDragOffset / 44, 1) * 0.25)
        }
        .offset(x: replyDragOffset)
        .simultaneousGesture(replyGesture)
        .accessibilityElement(children: .combine)
    }

    private var replyGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard value.translation.width > 0,
                      abs(value.translation.width) > abs(value.translation.height) else { return }
                replyDragOffset = min(value.translation.width * 0.7, 68)
            }
            .onEnded { value in
                let shouldReply = value.translation.width >= 58
                    && abs(value.translation.width) > abs(value.translation.height)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                    replyDragOffset = 0
                }
                if shouldReply { onReply() }
            }
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
        .accessibilityLabel(Text(isRead ? "Read" : "Sent"))
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
