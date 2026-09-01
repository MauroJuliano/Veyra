import Foundation
import Observation

@Observable
final class ProfileViewModel {
    private let store: any ProfileStore
    private(set) var profile: UserProfile
    var displayName: String
    var username: String
    private(set) var validationMessage: String?

    init(store: any ProfileStore = UserDefaultsProfileStore()) {
        self.store = store
        let profile = store.load()
        self.profile = profile
        displayName = profile.displayName
        username = profile.username
    }

    func save() -> Bool {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = username.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard name.count >= 2 else {
            validationMessage = "Enter a valid display name."
            return false
        }
        guard handle.count >= 3, !handle.contains(where: { $0.isWhitespace }) else {
            validationMessage = "Username must have at least 3 characters and no spaces."
            return false
        }
        let updated = UserProfile(displayName: name, username: handle.lowercased())
        store.save(updated)
        profile = updated
        displayName = updated.displayName
        username = updated.username
        validationMessage = nil
        return true
    }
}
