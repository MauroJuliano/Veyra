import Foundation
import Testing
@testable import Veyra

@MainActor
struct MessageTimelineViewModelTests {
    @Test func failedSendRemainsVisibleAndPersistedForRetry() async {
        let conversationID = UUID()
        let cache = InMemoryMessageCacheRepository()
        let viewModel = MessageTimelineViewModel(
            conversationID: conversationID,
            repository: OfflineRemoteChatRepository(),
            cache: cache,
            messages: []
        )
        viewModel.draft = "Send when online"

        await viewModel.send()

        guard let failed = viewModel.messages.first else {
            Issue.record("The failed message should remain visible")
            return
        }
        #expect(failed.deliveryState == .failed)
        #expect(viewModel.draft.isEmpty)
        #expect(cache.fetchMessages(conversationID: conversationID, before: nil, limit: 50).first?.id == failed.id)
    }

    @Test func loadsCachedMessagesWithoutRemoteRepository() async {
        let conversationID = UUID()
        let cachedMessage = Message(text: "Available offline", direction: .incoming)
        let cache = InMemoryMessageCacheRepository()
        cache.saveMessages([cachedMessage], conversationID: conversationID)
        let viewModel = MessageTimelineViewModel(
            conversationID: conversationID,
            repository: nil,
            cache: cache,
            messages: []
        )

        await viewModel.observeMessages()

        #expect(viewModel.messages.map(\.id) == [cachedMessage.id])
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasLoadedInitialPage)
    }

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

    @Test func deletesIncomingAndOutgoingMessagesForCurrentUser() async {
        let incoming = Message(text: "Hi", direction: .incoming)
        let outgoing = Message(text: "Hello", direction: .outgoing)
        let viewModel = MessageTimelineViewModel(messages: [incoming, outgoing])

        await viewModel.delete(incoming)
        #expect(viewModel.messages.map(\.id) == [outgoing.id])

        await viewModel.delete(outgoing)
        #expect(viewModel.messages.isEmpty)
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

    @Test func cachesAudioMessageMetadata() async {
        let conversationID = UUID()
        let audioURL = URL(string: "https://example.com/audio.m4a")!
        let message = Message(
            text: "Audio",
            direction: .incoming,
            audioURL: audioURL,
            audioDuration: 12.5
        )
        let cache = InMemoryMessageCacheRepository()
        cache.saveMessages([message], conversationID: conversationID)

        let restored = cache.fetchMessages(conversationID: conversationID, before: nil, limit: 50).first

        #expect(restored?.audioURL == audioURL)
        #expect(restored?.audioDuration == 12.5)
    }
}
