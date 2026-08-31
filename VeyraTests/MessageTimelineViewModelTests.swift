import Foundation
import Testing
@testable import Veyra

struct MessageTimelineViewModelTests {
    @Test func sendsTrimmedOutgoingMessageAndClearsDraft() {
        let viewModel = MessageTimelineViewModel(messages: [])
        viewModel.draft = "  Hello  "

        viewModel.send()

        #expect(viewModel.messages.count == 1)
        #expect(viewModel.messages[0].text == "Hello")
        #expect(viewModel.messages[0].direction == .outgoing)
        #expect(viewModel.draft.isEmpty)
    }

    @Test func ignoresEmptyDraft() {
        let viewModel = MessageTimelineViewModel(messages: [])
        viewModel.draft = "  \n "

        viewModel.send()

        #expect(viewModel.messages.isEmpty)
    }
}
