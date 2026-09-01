import Foundation
import Testing
@testable import Veyra

@MainActor
struct MessageTimelineViewModelTests {
    @Test func sendsTrimmedOutgoingMessageAndClearsDraft() async {
        let viewModel = MessageTimelineViewModel(messages: [])
        viewModel.draft = "  Hello  "

        await viewModel.send()

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].text == "Hello")
        #expect(viewModel.messages[0].direction == .outgoing)
        #expect(viewModel.draft.isEmpty)
    }

    @Test func ignoresEmptyDraft() async {
        let viewModel = MessageTimelineViewModel(messages: [])
        viewModel.draft = "  \n "

        await viewModel.send()

        #expect(viewModel.messages.isEmpty)
    }
}
