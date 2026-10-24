import Foundation

/// Estado del partido de un equipo de la NFL. Lo calcula quien lea `scores` (FN-008); el resolver solo lo traduce
/// a `PlayStatus`. Ver `docs/spikes/003-sleeper-live-data.md` §2.
public enum TeamGameState: Sendable, Equatable {
    case preGame
    case inProgress
    case over

    var playStatus: PlayStatus {
        switch self {
        case .preGame: .pending
        case .inProgress: .playing
        case .over: .done
        }
    }
}

public enum MatchupResolverError: Error, Equatable, Sendable {
    /// El usuario no es dueño ni co-dueño de ningún roster de la liga: la configuración es incorrecta.
    case rosterNotFound
}

/// Convierte las respuestas crudas de Sleeper en el `MatchupSnapshot` que consume la UI.
public enum MatchupResolver {
    /// - Parameters:
    ///   - players: jugadores de `PlayerCache` (solo `playerId`, `fullName`, `position` y `team` vienen poblados).
    ///   - gameStates: estado del partido por abreviatura de equipo (`Player.team`). Un equipo ausente, o un
    ///     jugador sin equipo, da `PlayStatus.unknown`.
    /// - Returns: `nil` si la semana no trae datos del roster del usuario (Sleeper responde `[]` fuera de
    ///   temporada); no es un error y el llamador no debe aplicar backoff por ello. Con `opponent == nil` si es
    ///   semana de bye o el `matchup_id` no tiene pareja.
    /// - Throws: `MatchupResolverError.rosterNotFound` si el usuario no tiene roster en la liga.
    ///
    /// Los puntos de cada equipo salen de `Matchup.points`; `custom_points` (ajuste manual del comisionado) se
    /// ignora porque ningún fixture lo trae y no está verificado cómo lo combina Sleeper.
    public static func resolve(
        week: Int,
        userId: String,
        rosters: [Roster],
        leagueUsers: [LeagueUser],
        matchups: [Matchup],
        players: [String: Player],
        gameStates: [String: TeamGameState] = [:],
        fetchedAt: Date,
        isStale: Bool = false
    ) throws -> MatchupSnapshot? {
        let roster =
            rosters.first { $0.ownerId == userId }
            ?? rosters.first { $0.coOwners?.contains(userId) == true }
        guard let roster else { throw MatchupResolverError.rosterNotFound }
        guard let mine = matchups.first(where: { $0.rosterId == roster.rosterId }) else { return nil }

        let rival = mine.matchupId.flatMap { id in
            matchups.first { $0.matchupId == id && $0.rosterId != mine.rosterId }
        }

        func score(_ matchup: Matchup) -> TeamScore {
            teamScore(
                matchup, rosters: rosters, leagueUsers: leagueUsers, players: players, gameStates: gameStates)
        }
        return MatchupSnapshot(
            week: week, me: score(mine), opponent: rival.map(score), fetchedAt: fetchedAt, isStale: isStale)
    }

    // MARK: - Piezas

    private static func teamScore(
        _ matchup: Matchup,
        rosters: [Roster],
        leagueUsers: [LeagueUser],
        players: [String: Player],
        gameStates: [String: TeamGameState]
    ) -> TeamScore {
        let ownerId = rosters.first { $0.rosterId == matchup.rosterId }?.ownerId
        let owner = ownerId.flatMap { id in leagueUsers.first { $0.userId == id } }

        let starters = matchup.starters.enumerated().compactMap { index, playerId -> StarterLine? in
            guard playerId != "0" else { return nil }  // slot vacío
            let player = players[playerId]
            let status = player?.team.flatMap { gameStates[$0] }?.playStatus ?? .unknown
            return StarterLine(
                playerId: playerId,
                name: player?.displayName ?? playerId,
                position: player?.position ?? "—",
                points: index < matchup.startersPoints.count ? matchup.startersPoints[index] : 0,
                status: status
            )
        }

        return TeamScore(
            rosterId: matchup.rosterId,
            teamName: nonEmpty(owner?.metadata?.teamName) ?? nonEmpty(owner?.displayName) ?? "Equipo \(matchup.rosterId)",
            avatarURL: nonEmpty(owner?.avatar).flatMap { URL(string: "https://sleepercdn.com/avatars/thumbs/\($0)") },
            points: matchup.points,
            starters: starters
        )
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}
