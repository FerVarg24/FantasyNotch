/// `GET /v1/league/{id}/rosters`.
public struct Roster: Codable, Sendable, Equatable {
    public struct Settings: Codable, Sendable, Equatable {
        public let wins: Int?
        public let losses: Int?
        public let ties: Int?

        public init(wins: Int? = nil, losses: Int? = nil, ties: Int? = nil) {
            self.wins = wins
            self.losses = losses
            self.ties = ties
        }
    }

    public let rosterId: Int
    /// `nil` cuando el roster no tiene dueño (equipo huérfano).
    public let ownerId: String?
    public let coOwners: [String]?
    public let players: [String]?
    public let starters: [String]?
    public let settings: Settings?

    enum CodingKeys: String, CodingKey {
        case rosterId = "roster_id"
        case ownerId = "owner_id"
        case coOwners = "co_owners"
        case players, starters, settings
    }

    public init(
        rosterId: Int,
        ownerId: String? = nil,
        coOwners: [String]? = nil,
        players: [String]? = nil,
        starters: [String]? = nil,
        settings: Settings? = nil
    ) {
        self.rosterId = rosterId
        self.ownerId = ownerId
        self.coOwners = coOwners
        self.players = players
        self.starters = starters
        self.settings = settings
    }
}
