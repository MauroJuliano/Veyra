protocol ContactRepository {
    func fetchContacts() -> [Contact]
    func saveContacts(_ contacts: [Contact])
}

final class InMemoryContactRepository: ContactRepository {
    private var storage: [Contact]

    init(contacts: [Contact] = []) {
        storage = contacts
    }

    func fetchContacts() -> [Contact] {
        storage.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func saveContacts(_ contacts: [Contact]) {
        storage = contacts
    }
}
