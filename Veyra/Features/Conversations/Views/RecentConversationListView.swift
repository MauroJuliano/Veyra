import SwiftUI

struct RecentConversationListView: View {
    @State var users: [User]

    init(users: [User]) {
        self.users = users
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(users) { user in
                RecentConversationRowView(user: user)

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
