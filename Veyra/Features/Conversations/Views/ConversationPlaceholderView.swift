import SwiftUI

struct ConversationPlaceholderView: View {
    let conversation: Conversation

    var body: some View {
        VStack(spacing: VeyraSpacing.md) {
            VeyraAvatar(name: conversation.participantName, size: .large, showsOnlineIndicator: conversation.isOnline)
            Text(conversation.participantName)
                .font(VeyraTypography.title)
                .foregroundStyle(VeyraColor.textPrimary)
            Text("The message timeline arrives in the next pull request.")
                .font(VeyraTypography.body)
                .foregroundStyle(VeyraColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(VeyraSpacing.xl)
        .background(VeyraColor.background)
        .navigationTitle(conversation.participantName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ConversationPlaceholderView(conversation: ConversationPreviewData.conversations[0])
    }
}
