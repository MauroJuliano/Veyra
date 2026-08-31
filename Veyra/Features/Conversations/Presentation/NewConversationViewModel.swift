import Foundation
import Observation

@Observable
final class NewConversationViewModel {
    let contacts: [Contact]
    var searchText = ""

    init(contacts: [Contact] = ContactPreviewData.contacts) {
        self.contacts = contacts.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var filteredContacts: [Contact] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return contacts }
        return contacts.filter { $0.name.localizedStandardContains(query) }
    }

    func conversation(for contact: Contact) -> Conversation {
        Conversation(participantName: contact.name, lastMessage: "Start a conversation", updatedAt: .now, isOnline: contact.isOnline)
    }
}
