import Foundation

enum MessagePreviewData {
    static func messages(for conversation: Conversation, now: Date = .now) -> [Message] {
        [
            Message(text: "Oi! Como está o projeto?", sentAt: now.addingTimeInterval(-3_600), direction: .incoming),
            Message(text: "Está evoluindo bem. Finalizei a primeira navegação.", sentAt: now.addingTimeInterval(-3_300), direction: .outgoing),
            Message(text: conversation.lastMessage, sentAt: now.addingTimeInterval(-240), direction: .incoming)
        ]
    }
}
