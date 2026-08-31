import Testing
@testable import Veyra

struct AppMetadataTests {
    @Test
    func applicationNameIsVeyra() {
        #expect(AppMetadata.name == "Veyra")
    }
}
