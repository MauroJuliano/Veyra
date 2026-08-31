import SwiftUI

struct AppRootView: View {
    var body: some View {
        NavigationStack {
            ConversationListView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case let .conversation(conversation):
                        MessageTimelineView(conversation: conversation)
                    }
                }
        }
        .tint(VeyraColor.accent)
    }
}

#Preview {
    AppRootView()
}
