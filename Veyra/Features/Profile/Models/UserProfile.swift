import Foundation

struct UserProfile: Codable, Equatable {
    var displayName: String
    var username: String
    var avatarURL: URL?
    var bio: String
    var email: String

    init(displayName: String, username: String, avatarURL: URL? = nil, bio: String = "", email: String = "") {
        self.displayName = displayName
        self.username = username
        self.avatarURL = avatarURL
        self.bio = bio
        self.email = email
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try container.decode(String.self, forKey: .displayName)
        username = try container.decode(String.self, forKey: .username)
        avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        bio = try container.decodeIfPresent(String.self, forKey: .bio) ?? ""
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
    }

    static let preview = UserProfile(displayName: "Veyra Member", username: "veyramember")

    var formattedUsername: String { "@\(username)" }
}
