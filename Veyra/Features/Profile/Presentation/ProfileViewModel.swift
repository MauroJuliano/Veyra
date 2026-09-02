import Foundation
import Observation

@Observable
final class ProfileViewModel {
    private let store: any ProfileStore
    private let remoteRepository: (any RemoteChatRepository)?
    private(set) var profile: UserProfile
    var displayName: String
    var username: String
    private(set) var validationMessage: String?
    private(set) var isUploadingAvatar = false

    init(store: any ProfileStore = UserDefaultsProfileStore(), remoteRepository: (any RemoteChatRepository)? = nil) {
        self.store = store
        self.remoteRepository = remoteRepository
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
        let updated = UserProfile(displayName: name, username: handle.lowercased(), avatarURL: profile.avatarURL)
        store.save(updated)
        profile = updated
        displayName = updated.displayName
        username = updated.username
        validationMessage = nil
        return true
    }

    @MainActor
    func loadRemoteProfile() async {
        guard let remoteRepository else { return }
        do {
            let remote = try await remoteRepository.fetchMyProfile()
            profile = remote
            displayName = remote.displayName
            username = remote.username
            store.save(remote)
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    @MainActor
    func updateAvatar(data: Data) async {
        guard let remoteRepository else { return }
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        do {
            profile = try await remoteRepository.updateMyAvatar(data)
            store.save(profile)
            validationMessage = nil
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
