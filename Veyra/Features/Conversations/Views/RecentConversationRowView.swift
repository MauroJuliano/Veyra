import SwiftUI

struct User: Identifiable, Hashable, Codable {
    let id: UUID
    let participantID: UUID?
    let participantName: String
    let userName: String
    let participantAvatarURL: URL?

    init(id: UUID = UUID(),
         participantID: UUID? = nil,
         participantName: String,
         userName: String,
         participantAvatarURL: URL?) {
        self.id = id
        self.participantID = participantID
        self.participantName = participantName
        self.userName = userName
        self.participantAvatarURL = participantAvatarURL
    }
}

struct RecentConversationRowView: View {
    let user: User
    var showsRemoveButton = true
    var onRemove: () -> Void = {}

    var body: some View {
        HStack(spacing: VeyraSpacing.md) {
            VeyraAvatar(name: user.participantName, imageURL: user.participantAvatarURL)

            VStack(alignment: .leading, spacing: VeyraSpacing.xs) {
                Text(user.participantName)
                    .font(VeyraTypography.bodyEmphasized)
                    .foregroundStyle(VeyraColor.textPrimary)
                Text(user.userName)
                    .font(VeyraTypography.body)
                    .foregroundStyle(VeyraColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if showsRemoveButton {
                Button(action: onRemove) {
                    Image(systemName: "xmark").padding(VeyraSpacing.md)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(user.participantName) from recent searches")
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(VeyraColor.textSecondary)
                    .padding(VeyraSpacing.md)
            }
        }
        .padding(VeyraSpacing.md)
        .contentShape(Rectangle())
    }
}

#Preview("Conversation row") {
    RecentConversationRowView(user: RecentConversationPreviewData.users[0])
        .background(VeyraColor.surface)
        .padding()
        .background(VeyraColor.background)
}
