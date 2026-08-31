import Foundation

enum ConversationPreviewData {
    static let conversations = [
        Conversation(participantName: "Ana Lima", lastMessage: "Vamos revisar o protótipo amanhã?", updatedAt: .now.addingTimeInterval(-240), unreadCount: 2, isOnline: true),
        Conversation(participantName: "Lucas Rocha", lastMessage: "A nova navegação ficou muito boa.", updatedAt: .now.addingTimeInterval(-3_600)),
        Conversation(participantName: "Marina Costa", lastMessage: "Te envio as referências mais tarde.", updatedAt: .now.addingTimeInterval(-86_400), unreadCount: 1, isOnline: true),
        Conversation(participantName: "Rafael Alves", lastMessage: "Obrigado pela ajuda!", updatedAt: .now.addingTimeInterval(-172_800))
    ]
}
