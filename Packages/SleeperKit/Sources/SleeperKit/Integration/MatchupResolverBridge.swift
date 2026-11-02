/// Puente entre el poller (`MatchupResolving`) y la lógica pura de FN-007 (`MatchupResolver`).
///
/// El poller conoce el estado del partido como `TeamPlayState` (FN-008) y el resolver como `TeamGameState` (FN-007):
/// son los mismos tres casos, y aquí se traducen. `fetchedAt` e `isStale` se ignoran porque los fija el poller.
public struct MatchupResolverBridge: MatchupResolving {
    public init() {}

    public func resolve(_ input: MatchupInput) throws -> MatchupSnapshot? {
        try MatchupResolver.resolve(
            week: input.week,
            userId: input.userId,
            rosters: input.rosters,
            leagueUsers: input.leagueUsers,
            matchups: input.matchups,
            players: input.players,
            gameStates: input.teamStates.mapValues(Self.gameState),
            fetchedAt: .distantPast
        )
    }

    private static func gameState(_ state: TeamPlayState) -> TeamGameState {
        switch state {
        case .preGame: .preGame
        case .inProgress: .inProgress
        case .over: .over
        }
    }
}
