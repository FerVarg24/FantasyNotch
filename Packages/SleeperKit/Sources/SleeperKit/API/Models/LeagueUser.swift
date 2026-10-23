/// `GET /v1/league/{id}/users`. `metadata` mezcla tipos; solo se decodifica `team_name`.
public struct LeagueUser: Codable, Sendable, Equatable {
    public struct Metadata: Codable, Sendable, Equatable {
        public let teamName: String?

        enum CodingKeys: String, CodingKey {
            case teamName = "team_name"
        }

        public init(teamName: String? = nil) {
            self.teamName = teamName
        }
    }

    public let userId: String
    public let displayName: String?
    public let avatar: String?
    public let isOwner: Bool?
    public let metadata: Metadata?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case avatar
        case isOwner = "is_owner"
        case metadata
    }

    public init(
        userId: String,
        displayName: String? = nil,
        avatar: String? = nil,
        isOwner: Bool? = nil,
        metadata: Metadata? = nil
    ) {
        self.userId = userId
        self.displayName = displayName
        self.avatar = avatar
        self.isOwner = isOwner
        self.metadata = metadata
    }
}
