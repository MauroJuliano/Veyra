import SwiftUI

struct AppRootView: View {
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies = AppDependencies()) {
        self.dependencies = dependencies
    }

    var body: some View {
        NavigationStack {
            ConversationListView(
                viewModel: ConversationListViewModel(repository: dependencies.conversations),
                contactRepository: dependencies.contacts
            )
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
