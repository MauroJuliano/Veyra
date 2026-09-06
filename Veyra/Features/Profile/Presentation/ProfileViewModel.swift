import Foundation
import Observation

@Observable
final class ProfileViewModel {
    private let store: any ProfileStore
    private let remoteRepository: (any RemoteChatRepository)?
    private(set) var profile: UserProfile
    var displayName: String
    var username: String
    var email: String
    var bio: String
    var isSaving = false
    private(set) var validationMessage: String?
    private(set) var isUploadingAvatar = false
    var profileRepository: (any RemoteChatRepository)? { remoteRepository }

    init(store: any ProfileStore = UserDefaultsProfileStore(), remoteRepository: (any RemoteChatRepository)? = nil) {
        self.store = store
        self.remoteRepository = remoteRepository
        let profile = store.load()
        self.profile = profile
        displayName = profile.displayName
        username = profile.username
        bio = profile.bio
        email = profile.email
    }

    @MainActor
    func save() async -> Bool {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = username.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else {
            validationMessage = String(localized: "Enter a valid display name.")
            return false
        }
        let validUsername = handle.range(of: "^[a-zA-Z0-9_]{3,30}$", options: .regularExpression) != nil
        guard validUsername else {
            validationMessage = String(localized: "Username must have 3–30 letters, numbers or underscores.")
            return false
        }
        guard normalizedEmail.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) != nil else {
            validationMessage = String(localized: "Enter a valid email address.")
            return false
        }
        guard normalizedBio.count <= 120 else {
            validationMessage = String(localized: "Bio must contain at most 120 characters.")
            return false
        }

        isSaving = true
        defer { isSaving = false }
        let updated: UserProfile
        if let remoteRepository {
            do {
                updated = try await remoteRepository.updateMyProfile(
                    displayName: name,
                    username: handle.lowercased(),
                    bio: normalizedBio,
                    email: normalizedEmail
                )
            } catch {
                let description = error.localizedDescription.lowercased()
                if description.contains("username") || description.contains("profiles_username_key") {
                    validationMessage = String(localized: "This username is already in use.")
                } else if description.contains("email") || description.contains("already registered") {
                    validationMessage = String(localized: "This email is already in use.")
                } else {
                    validationMessage = error.localizedDescription
                }
                return false
            }
        } else {
            updated = UserProfile(displayName: name, username: handle.lowercased(), avatarURL: profile.avatarURL, bio: normalizedBio, email: normalizedEmail)
        }
        store.save(updated)
        profile = updated
        displayName = updated.displayName
        username = updated.username
        email = updated.email
        bio = updated.bio
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
            email = remote.email
            bio = remote.bio
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
            displayName = profile.displayName
            username = profile.username
            email = profile.email
            bio = profile.bio
            store.save(profile)
            validationMessage = nil
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
