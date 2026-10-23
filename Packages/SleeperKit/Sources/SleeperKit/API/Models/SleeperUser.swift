/// `GET /v1/user/{username}`. Solo los campos que usa la app; el resto de la respuesta se ignora.
public struct SleeperUser: Codable, Sendable, Equatable {
    public let userId: String
    public let username: String?
    public let displayName: String?
    public let avatar: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatar
    }

    public init(userId: String, username: String? = nil, displayName: String? = nil, avatar: String? = nil) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.avatar = avatar
    }
}
