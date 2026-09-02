import Foundation
import Testing
@testable import Veyra

struct AvatarInitialsTests {
    @Test(arguments: [
        ("Mauro Figueiredo", "MF"),
        ("Veyra", "V"),
        ("  Ada   Lovelace  ", "AL"),
        ("", "")
    ])
    func createsInitials(name: String, expected: String) {
        #expect(AvatarInitials.make(from: name) == expected)
    }
}

struct ImagePipelineCacheKeyTests {
    @Test func ignoresRotatingSignedURLQuery() {
        let first = URL(string: "https://project.supabase.co/storage/v1/object/sign/avatars/user/photo.jpg?token=first")!
        let second = URL(string: "https://project.supabase.co/storage/v1/object/sign/avatars/user/photo.jpg?token=second")!

        #expect(VeyraImagePipeline.cacheKey(for: first) == VeyraImagePipeline.cacheKey(for: second))
    }

    @Test func immutableAvatarPathsProduceDifferentKeys() {
        let first = URL(string: "https://project.supabase.co/storage/v1/object/sign/avatars/user/one.jpg")!
        let second = URL(string: "https://project.supabase.co/storage/v1/object/sign/avatars/user/two.jpg")!

        #expect(VeyraImagePipeline.cacheKey(for: first) != VeyraImagePipeline.cacheKey(for: second))
    }
}
