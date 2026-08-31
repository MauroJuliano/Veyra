protocol ContactRepository {
    func fetchContacts() -> [Contact]
}

final class InMemoryContactRepository: ContactRepository {
    private let storage: [Contact]

    init(contacts: [Contact] = ContactPreviewData.contacts) {
        storage = contacts
    }

    func fetchContacts() -> [Contact] {
        storage.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
