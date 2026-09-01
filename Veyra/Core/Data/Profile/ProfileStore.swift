import Foundation

protocol ProfileStore {
    func load() -> UserProfile
    func save(_ profile: UserProfile)
}

final class UserDefaultsProfileStore: ProfileStore {
    private let defaults: UserDefaults
    private let key = "veyra.profile"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> UserProfile {
        guard let data = defaults.data(forKey: key),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return .preview }
        return profile
    }

    func save(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }
}

final class InMemoryProfileStore: ProfileStore {
    private var profile: UserProfile

    init(profile: UserProfile = .preview) {
        self.profile = profile
    }

    func load() -> UserProfile { profile }
    func save(_ profile: UserProfile) { self.profile = profile }
}
