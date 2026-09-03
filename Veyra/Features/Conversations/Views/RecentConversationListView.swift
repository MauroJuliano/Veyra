import SwiftUI

struct RecentConversationListView: View {
    let users: [User]
    var showsRemoveButtons: Bool
    var onSelect: (User) -> Void
    var onRemove: (User) -> Void

    init(users: [User], showsRemoveButtons: Bool = true, onSelect: @escaping (User) -> Void = { _ in }, onRemove: @escaping (User) -> Void = { _ in }) {
        self.users = users
        self.showsRemoveButtons = showsRemoveButtons
        self.onSelect = onSelect
        self.onRemove = onRemove
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(users) { user in
                Button { onSelect(user) } label: {
                    RecentConversationRowView(user: user, showsRemoveButton: showsRemoveButtons, onRemove: { onRemove(user) })
                }
                .buttonStyle(.plain)

                if user.id != users.last?.id {
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            GlassBackground()
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }
}
