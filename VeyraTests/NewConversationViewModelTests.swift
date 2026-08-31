import Testing
@testable import Veyra

struct NewConversationViewModelTests {
    @Test func filtersContactsByName() {
        let viewModel = NewConversationViewModel(contacts: [
            Contact(name: "Beatriz Souza"),
            Contact(name: "Daniel Martins")
        ])
        viewModel.searchText = "bia"

        #expect(viewModel.filteredContacts.isEmpty)

        viewModel.searchText = "beatriz"
        #expect(viewModel.filteredContacts.map(\.name) == ["Beatriz Souza"])
    }

    @Test func createsEmptyConversationForSelectedContact() {
        let contact = Contact(name: "Helena Ribeiro", isOnline: true)
        let conversation = NewConversationViewModel(contacts: [contact]).conversation(for: contact)

        #expect(conversation.participantName == contact.name)
        #expect(conversation.isOnline)
        #expect(conversation.unreadCount == 0)
    }
}
