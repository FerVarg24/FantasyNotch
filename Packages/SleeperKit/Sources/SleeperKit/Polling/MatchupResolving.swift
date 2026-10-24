/// Datos crudos de un refresco, tal como los entrega el poller al resolver.
public struct MatchupInput: Sendable {
    public let week: Int
    public let userId: String
    public let rosters: [Roster]
    public let leagueUsers: [LeagueUser]
    public let matchups: [Matchup]
    public let players: [String: Player]
    public let teamStates: [String: TeamPlayState]

    public init(
        week: Int,
        userId: String,
        rosters: [Roster],
        leagueUsers: [LeagueUser],
        matchups: [Matchup],
        players: [String: Player],
        teamStates: [String: TeamPlayState]
    ) {
        self.week = week
        self.userId = userId
        self.rosters = rosters
        self.leagueUsers = leagueUsers
        self.matchups = matchups
        self.players = players
        self.teamStates = teamStates
    }
}

/// Punto de inyección del resolver (lo implementa FN-007 con `MatchupResolver`; el puente lo hace FN-011).
///
/// - Devuelve `nil` cuando el usuario no tiene datos esta semana: no es un fallo, no se emite nada y no hay backoff.
/// - Lanza cuando la configuración es mala (por ejemplo, el roster no existe): cuenta como refresco fallido.
/// - `fetchedAt` e `isStale` del snapshot devuelto se **ignoran**: los fija el poller con su reloj.
public protocol MatchupResolving: Sendable {
    func resolve(_ input: MatchupInput) throws -> MatchupSnapshot?
}
