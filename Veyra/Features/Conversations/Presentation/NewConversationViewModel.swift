import Foundation
import Observation

@Observable
final class NewConversationViewModel {
    let contacts: [Contact]
    var searchText = ""

    init(repository: any ContactRepository = InMemoryContactRepository()) {
        contacts = repository.fetchContacts()
    }

    convenience init(contacts: [Contact]) {
        self.init(repository: InMemoryContactRepository(contacts: contacts))
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
