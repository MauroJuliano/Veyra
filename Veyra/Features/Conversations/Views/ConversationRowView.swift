import SwiftUI

struct ConversationRowView: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: VeyraSpacing.md) {
            VeyraAvatar(name: conversation.participantName, showsOnlineIndicator: conversation.isOnline)

            VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(conversation.participantName)
                        .font(VeyraTypography.bodyEmphasized)
                        .foregroundStyle(VeyraColor.textPrimary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(conversation.updatedAt, format: .relative(presentation: .named))
                            .font(VeyraTypography.caption)
                            .foregroundStyle(VeyraColor.textSecondary)
                    }
                }

                HStack {
                    Text(conversation.lastMessage)
                        .font(VeyraTypography.body)
                        .foregroundStyle(VeyraColor.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: VeyraSpacing.sm)
                    if conversation.unreadCount > 0 {
                        Text(conversation.unreadCount, format: .number)
                            .font(VeyraTypography.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(VeyraColor.accent)
                            .clipShape(Circle())
                            .accessibilityLabel("\(conversation.unreadCount) unread messages")
                    }

                    if conversation.lastMessageIsMine {
                        MessageReceiptIcon(isRead: conversation.lastMessageIsRead)
                            .font(VeyraTypography.caption)
                    }
                }
            }
        }
        .padding(VeyraSpacing.md)
        .contentShape(Rectangle())
    }
}

#Preview("Conversation row") {
    ConversationRowView(conversation: ConversationPreviewData.conversations[0])
        .background(VeyraColor.surface)
        .padding()
        .background(VeyraColor.background)
}
