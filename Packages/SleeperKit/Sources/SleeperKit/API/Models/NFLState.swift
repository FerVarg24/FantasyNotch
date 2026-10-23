/// `GET /v1/state/nfl`: semana y temporada actuales.
public struct NFLState: Codable, Sendable, Equatable {
    public let week: Int
    public let season: String
    public let seasonType: String
    public let leagueSeason: String?
    public let displayWeek: Int?
    public let previousSeason: String?
    public let seasonStartDate: String?

    enum CodingKeys: String, CodingKey {
        case week, season
        case seasonType = "season_type"
        case leagueSeason = "league_season"
        case displayWeek = "display_week"
        case previousSeason = "previous_season"
        case seasonStartDate = "season_start_date"
    }

    public init(
        week: Int,
        season: String,
        seasonType: String,
        leagueSeason: String? = nil,
        displayWeek: Int? = nil,
        previousSeason: String? = nil,
        seasonStartDate: String? = nil
    ) {
        self.week = week
        self.season = season
        self.seasonType = seasonType
        self.leagueSeason = leagueSeason
        self.displayWeek = displayWeek
        self.previousSeason = previousSeason
        self.seasonStartDate = seasonStartDate
    }
}
