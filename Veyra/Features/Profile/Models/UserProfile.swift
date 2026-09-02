import Foundation

struct UserProfile: Codable, Equatable {
    var displayName: String
    var username: String
    var avatarURL: URL?

    static let preview = UserProfile(displayName: "Veyra Member", username: "veyramember", avatarURL: nil)

    var formattedUsername: String { "@\(username)" }
}
