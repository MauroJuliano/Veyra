import Foundation

protocol SessionStore {
    var isAuthenticated: Bool { get }
    func setAuthenticated(_ isAuthenticated: Bool)
}

final class UserDefaultsSessionStore: SessionStore {
    private enum Key {
        static let isAuthenticated = "veyra.session.isAuthenticated"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isAuthenticated: Bool {
        defaults.bool(forKey: Key.isAuthenticated)
    }

    func setAuthenticated(_ isAuthenticated: Bool) {
        defaults.set(isAuthenticated, forKey: Key.isAuthenticated)
    }
}

final class InMemorySessionStore: SessionStore {
    private(set) var isAuthenticated: Bool

    init(isAuthenticated: Bool = false) {
        self.isAuthenticated = isAuthenticated
    }

    func setAuthenticated(_ isAuthenticated: Bool) {
        self.isAuthenticated = isAuthenticated
    }
}
