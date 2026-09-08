import Testing
@testable import Veyra

struct SessionStoreTests {
    @Test func storesAndClearsAuthenticationState() {
        let store = InMemorySessionStore()
        #expect(!store.isAuthenticated)

        store.setAuthenticated(true)
        #expect(store.isAuthenticated)

        store.setAuthenticated(false)
        #expect(!store.isAuthenticated)
    }
}
