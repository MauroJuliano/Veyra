import Foundation

struct Contact: Identifiable, Hashable {
    let id: UUID
    let name: String
    let isOnline: Bool

    init(id: UUID = UUID(), name: String, isOnline: Bool = false) {
        self.id = id
        self.name = name
        self.isOnline = isOnline
    }
}
