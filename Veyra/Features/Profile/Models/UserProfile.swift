struct UserProfile: Codable, Equatable {
    var displayName: String
    var username: String

    static let preview = UserProfile(displayName: "Veyra Member", username: "veyramember")

    var formattedUsername: String { "@\(username)" }
}
