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

    @Test func deletesOnlyOutgoingMessages() async {
        let incoming = Message(text: "Hi", direction: .incoming)
        let outgoing = Message(text: "Hello", direction: .outgoing)
        let viewModel = MessageTimelineViewModel(messages: [incoming, outgoing])

        await viewModel.delete(incoming)
        #expect(viewModel.messages.map(\.id) == [incoming.id, outgoing.id])

        await viewModel.delete(outgoing)
        #expect(viewModel.messages.map(\.id) == [incoming.id])
    }

    @Test func sendsReplyWithOriginalMessagePreview() async {
        let original = Message(text: "Original message", direction: .incoming)
        let viewModel = MessageTimelineViewModel(messages: [original])
        viewModel.beginReply(to: original)
        viewModel.draft = "My reply"

        await viewModel.send()

        #expect(viewModel.messages.last?.replyPreview?.messageID == original.id)
        #expect(viewModel.messages.last?.replyPreview?.text == "Original message")
        #expect(viewModel.replyingTo == nil)
    }

    @Test func cancelsReplySelection() {
        let original = Message(text: "Original message", direction: .incoming)
        let viewModel = MessageTimelineViewModel(messages: [original])

        viewModel.beginReply(to: original)
        viewModel.cancelReply()

        #expect(viewModel.replyingTo == nil)
    }
}
