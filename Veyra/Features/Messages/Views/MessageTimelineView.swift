import SwiftUI

struct MessageTimelineView: View {
    let conversation: Conversation
    @State private var viewModel: MessageTimelineViewModel

    init(conversation: Conversation, messages: [Message]? = nil) {
        self.conversation = conversation
        _viewModel = State(initialValue: MessageTimelineViewModel(messages: messages ?? MessagePreviewData.messages(for: conversation)))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: VeyraSpacing.sm) {
                    ForEach(viewModel.days) { day in
                        Text(day.date, format: .dateTime.day().month(.wide))
                            .font(VeyraTypography.caption)
                            .foregroundStyle(VeyraColor.textSecondary)
                            .padding(.vertical, VeyraSpacing.sm)
                        ForEach(day.messages) { message in
                            MessageBubbleView(message: message)
                        }
                    }
                }
                .padding(VeyraSpacing.md)
            }

            Divider().overlay(VeyraColor.divider)
            MessageComposerView(text: $viewModel.draft, canSend: viewModel.canSend, onSend: viewModel.send)
        }
        .background(VeyraColor.background)
        .navigationTitle(conversation.participantName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Timeline - Dark") {
    NavigationStack {
        MessageTimelineView(conversation: ConversationPreviewData.conversations[0])
    }
    .preferredColorScheme(.dark)
}
