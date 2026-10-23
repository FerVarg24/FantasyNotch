/// `GET /v1/league/{id}/matchups/{week}`: una entrada por roster.
///
/// - `matchupId` es el mismo valor para los dos rosters que se enfrentan; es `nil` en bye o playoffs sin cruce.
/// - `starters[i]` corresponde a `startersPoints[i]` (orden de slots). Un slot vacío viene como `"0"`.
/// - Las posiciones DEF usan el código del equipo como ID (`"NE"`), por eso los IDs son `String`.
public struct Matchup: Codable, Sendable, Equatable {
    public let rosterId: Int
    public let matchupId: Int?
    public let points: Double
    public let customPoints: Double?
    public let starters: [String]
    public let startersPoints: [Double]
    public let players: [String]
    public let playersPoints: [String: Double]

    enum CodingKeys: String, CodingKey {
        case rosterId = "roster_id"
        case matchupId = "matchup_id"
        case points
        case customPoints = "custom_points"
        case starters
        case startersPoints = "starters_points"
        case players
        case playersPoints = "players_points"
    }

    public init(
        rosterId: Int,
        matchupId: Int?,
        points: Double,
        customPoints: Double? = nil,
        starters: [String],
        startersPoints: [Double],
        players: [String],
        playersPoints: [String: Double]
    ) {
        self.rosterId = rosterId
        self.matchupId = matchupId
        self.points = points
        self.customPoints = customPoints
        self.starters = starters
        self.startersPoints = startersPoints
        self.players = players
        self.playersPoints = playersPoints
    }

    /// Sleeper omite o anula listas fuera de temporada: se tratan como vacías en vez de fallar.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rosterId = try c.decode(Int.self, forKey: .rosterId)
        matchupId = try c.decodeIfPresent(Int.self, forKey: .matchupId)
        points = try c.decodeIfPresent(Double.self, forKey: .points) ?? 0
        customPoints = try c.decodeIfPresent(Double.self, forKey: .customPoints)
        starters = try c.decodeIfPresent([String].self, forKey: .starters) ?? []
        startersPoints = try c.decodeIfPresent([Double].self, forKey: .startersPoints) ?? []
        players = try c.decodeIfPresent([String].self, forKey: .players) ?? []
        playersPoints = try c.decodeIfPresent([String: Double].self, forKey: .playersPoints) ?? [:]
    }
}
