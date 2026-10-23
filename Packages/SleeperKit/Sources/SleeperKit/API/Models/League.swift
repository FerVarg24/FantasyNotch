/// `GET /v1/user/{id}/leagues/nfl/{season}`. `settings` y `scoring_settings` se omiten a propósito:
/// mezclan tipos y no hacen falta para mostrar el marcador.
public struct League: Codable, Sendable, Equatable {
    public let leagueId: String
    public let name: String
    public let season: String?
    public let status: String?
    public let totalRosters: Int?
    public let avatar: String?
    public let rosterPositions: [String]?

    enum CodingKeys: String, CodingKey {
        case leagueId = "league_id"
        case name, season, status, avatar
        case totalRosters = "total_rosters"
        case rosterPositions = "roster_positions"
    }

    public init(
        leagueId: String,
        name: String,
        season: String? = nil,
        status: String? = nil,
        totalRosters: Int? = nil,
        avatar: String? = nil,
        rosterPositions: [String]? = nil
    ) {
        self.leagueId = leagueId
        self.name = name
        self.season = season
        self.status = status
        self.totalRosters = totalRosters
        self.avatar = avatar
        self.rosterPositions = rosterPositions
    }
}
