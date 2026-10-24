import Foundation
import Testing

@testable import SleeperKit
@testable import SleeperKitMocks

@Suite("MatchupResolver: de datos crudos a MatchupSnapshot")
struct MatchupResolverTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Fixtures reales

    /// Lo que el resolver recibe en producción: `PlayerCache` solo conserva 4 campos por jugador.
    private static func cachedPlayers(_ api: MockSleeperAPI) async throws -> [String: Player] {
        try await api.players().mapValues {
            Player(playerId: $0.playerId, fullName: $0.fullName, position: $0.position, team: $0.team)
        }
    }

    private func resolveFixture(
        _ scenario: MockSleeperAPI.Scenario, userId: String, gameStates: [String: TeamGameState] = [:]
    ) async throws -> (snapshot: MatchupSnapshot?, matchups: [Matchup]) {
        let api = MockSleeperAPI(scenario: scenario)
        let matchups = try await api.matchups(leagueId: "x", week: 1)
        let snapshot = try MatchupResolver.resolve(
            week: 1,
            userId: userId,
            rosters: try await api.rosters(leagueId: "x"),
            leagueUsers: try await api.leagueUsers(leagueId: "x"),
            matchups: matchups,
            players: try await Self.cachedPlayers(api),
            gameStates: gameStates,
            fetchedAt: Self.now
        )
        return (snapshot, matchups)
    }

    @Test("Partido en vivo: encuentra mi roster, a mi rival por matchup_id y los puntos de cada titular")
    func liveMatchup() async throws {
        let (resolved, matchups) = try await resolveFixture(.live, userId: "900000000000000001")
        let snapshot = try #require(resolved)

        #expect(snapshot.me.rosterId == 2)
        #expect(snapshot.me.teamName == "Equipo 1")
        let mine = try #require(matchups.first { $0.rosterId == 2 })
        let rival = try #require(snapshot.opponent)
        #expect(rival.rosterId != 2)
        #expect(matchups.first { $0.rosterId == rival.rosterId }?.matchupId == mine.matchupId)

        #expect(snapshot.me.points == mine.points)
        let expected = zip(mine.starters, mine.startersPoints).filter { $0.0 != "0" }
        #expect(snapshot.me.starters.map(\.playerId) == expected.map(\.0))
        #expect(snapshot.me.starters.map(\.points) == expected.map(\.1))
        #expect(snapshot.me.starters.contains { $0.points == 0 })
        #expect(snapshot.week == 1)
        #expect(snapshot.fetchedAt == Self.now)
        #expect(!snapshot.isStale)
    }

    @Test("Semana de bye: matchup_id nulo da opponent == nil")
    func byeWeek() async throws {
        let (bye, _) = try await resolveFixture(.bye, userId: "900000000000000004")
        let snapshot = try #require(bye)

        #expect(snapshot.me.rosterId == 3)
        #expect(snapshot.opponent == nil)
    }

    @Test("Slot vacío \"0\" real (roster 12, semana 14): se omite y los puntos siguen alineados con su titular")
    func emptySlotInRealFixture() async throws {
        let (resolved, matchups) = try await resolveFixture(.bye, userId: "900000000000000006")
        let snapshot = try #require(resolved)
        let raw = try #require(matchups.first { $0.rosterId == 12 })
        let emptyIndex = try #require(raw.starters.firstIndex(of: "0"))

        #expect(snapshot.me.rosterId == 12)
        #expect(snapshot.me.starters.count == raw.starters.count - 1)
        #expect(!snapshot.me.starters.contains { $0.playerId == "0" })
        let after = try #require(snapshot.me.starters.first { $0.playerId == raw.starters[emptyIndex + 1] })
        #expect(after.points == raw.startersPoints[emptyIndex + 1])
    }

    @Test("Semana de playoffs con cruce: los rosters 1 y 5 comparten matchup_id")
    func playoffsPairing() async throws {
        // En rosters.json el roster 1 es de 900000000000000010.
        let (resolved, _) = try await resolveFixture(.bye, userId: "900000000000000010")
        let snapshot = try #require(resolved)

        #expect(snapshot.me.rosterId == 1)
        #expect(snapshot.opponent?.rosterId == 5)
    }

    @Test("Semana sin datos: devuelve nil en vez de lanzar")
    func emptyWeekReturnsNil() async throws {
        let (snapshot, _) = try await resolveFixture(.empty, userId: "900000000000000001")
        #expect(snapshot == nil)
    }

    @Test("Un usuario sin roster en la liga es un error de configuración")
    func unknownUserThrows() async throws {
        await #expect(throws: MatchupResolverError.rosterNotFound) {
            _ = try await resolveFixture(.final, userId: "no-existe")
        }
    }

    // MARK: - Casos construidos a mano

    private static func matchup(
        _ rosterId: Int, id: Int?, starters: [String], points: [Double], total: Double = 0
    ) -> Matchup {
        Matchup(
            rosterId: rosterId, matchupId: id, points: total, starters: starters, startersPoints: points,
            players: starters, playersPoints: [:])
    }

    private static let players: [String: Player] = [
        "1": Player(playerId: "1", fullName: "Uno", position: "QB", team: "KC"),
        "2": Player(playerId: "2", fullName: "Dos", position: "RB", team: "PHI"),
        "3": Player(playerId: "3", fullName: "Tres", position: "WR", team: "DAL"),
        "PHI": Player(playerId: "PHI", position: "DEF", team: "PHI"),
    ]

    private func resolve(
        userId: String = "u1",
        rosters: [Roster] = [Roster(rosterId: 1, ownerId: "u1"), Roster(rosterId: 2, ownerId: "u2")],
        leagueUsers: [LeagueUser] = [],
        matchups: [Matchup],
        gameStates: [String: TeamGameState] = [:],
        isStale: Bool = false
    ) throws -> MatchupSnapshot? {
        try MatchupResolver.resolve(
            week: 7, userId: userId, rosters: rosters, leagueUsers: leagueUsers, matchups: matchups,
            players: Self.players, gameStates: gameStates, fetchedAt: Self.now, isStale: isStale)
    }

    private let pair = [
        matchup(1, id: 3, starters: ["1"], points: [10], total: 10),
        matchup(2, id: 3, starters: ["2"], points: [5], total: 5),
    ]

    @Test("PlayStatus sale del estado del partido del equipo del jugador")
    func playStatusFromGameStates() throws {
        let matchups = [
            Self.matchup(1, id: 3, starters: ["1", "2", "3", "PHI"], points: [1, 2, 3, 4], total: 10),
            Self.matchup(2, id: 3, starters: [], points: []),
        ]
        let states: [String: TeamGameState] = ["KC": .inProgress, "PHI": .over, "DAL": .preGame]

        let lines = try #require(try resolve(matchups: matchups, gameStates: states)).me.starters

        #expect(lines.map(\.status) == [.playing, .done, .pending, .done])
    }

    @Test("Sin datos del partido (o equipo ausente) el estado es unknown")
    func playStatusUnknownWithoutData() throws {
        let none = try #require(try resolve(matchups: pair))
        #expect(none.me.starters.map(\.status) == [.unknown])

        let missingTeam = try #require(try resolve(matchups: pair, gameStates: ["DAL": .over]))
        #expect(missingTeam.me.starters.map(\.status) == [.unknown])
    }

    @Test("Jugador ausente del diccionario: nombre = id, posición —, estado unknown")
    func missingPlayerIsKept() throws {
        let matchups = [
            Self.matchup(1, id: 3, starters: ["999"], points: [7.5], total: 7.5),
            Self.matchup(2, id: 3, starters: [], points: []),
        ]
        let line = try #require(try resolve(matchups: matchups, gameStates: ["KC": .over])).me.starters[0]

        #expect(line == StarterLine(playerId: "999", name: "999", position: "—", points: 7.5, status: .unknown))
    }

    @Test("starters_points más corto que starters rellena con 0 y el slot \"0\" se omite")
    func shortPointsAndEmptySlot() throws {
        let matchups = [
            Self.matchup(1, id: 3, starters: ["1", "0", "2"], points: [4]),
            Self.matchup(2, id: 3, starters: [], points: []),
        ]
        let lines = try #require(try resolve(matchups: matchups)).me.starters

        #expect(lines.map(\.playerId) == ["1", "2"])
        #expect(lines.map(\.points) == [4, 0])
    }

    @Test("Nombre del equipo: team_name, luego display_name, luego Equipo N")
    func teamNameFallbacks() throws {
        let users = [
            LeagueUser(userId: "u1", displayName: "Ana", metadata: .init(teamName: "Las Águilas")),
            LeagueUser(userId: "u2", displayName: "Beto", metadata: .init(teamName: "")),
        ]
        let named = try #require(try resolve(leagueUsers: users, matchups: pair))
        #expect(named.me.teamName == "Las Águilas")
        #expect(named.opponent?.teamName == "Beto")

        let orphan = try #require(
            try resolve(
                rosters: [Roster(rosterId: 1, ownerId: "u1"), Roster(rosterId: 2)], leagueUsers: users, matchups: pair))
        #expect(orphan.opponent?.teamName == "Equipo 2")
    }

    @Test("Avatar: sleepercdn.com/avatars/thumbs/<id>; vacío o ausente es nil")
    func avatarURL() throws {
        let users = [
            LeagueUser(userId: "u1", avatar: "abc123"),
            LeagueUser(userId: "u2", avatar: ""),
        ]
        let snapshot = try #require(try resolve(leagueUsers: users, matchups: pair))
        #expect(snapshot.me.avatarURL == URL(string: "https://sleepercdn.com/avatars/thumbs/abc123"))
        #expect(snapshot.opponent?.avatarURL == nil)

        let noUsers = try #require(try resolve(matchups: pair))
        #expect(noUsers.me.avatarURL == nil)
    }

    @Test("Un co-owner también encuentra su roster")
    func coOwnerFindsRoster() throws {
        let rosters = [Roster(rosterId: 1, ownerId: "u9", coOwners: ["u1"]), Roster(rosterId: 2, ownerId: "u2")]
        let snapshot = try #require(try resolve(rosters: rosters, matchups: pair))
        #expect(snapshot.me.rosterId == 1)
    }

    @Test("matchup_id sin pareja da opponent == nil")
    func unpairedMatchupHasNoOpponent() throws {
        let matchups = [
            Self.matchup(1, id: 3, starters: ["1"], points: [10], total: 10),
            Self.matchup(2, id: 4, starters: ["2"], points: [5], total: 5),
        ]
        let snapshot = try #require(try resolve(matchups: matchups))
        #expect(snapshot.opponent == nil)
    }

    @Test("week, fetchedAt e isStale se copian tal cual")
    func passthroughFields() throws {
        let snapshot = try #require(try resolve(matchups: pair, isStale: true))
        #expect(snapshot.week == 7)
        #expect(snapshot.fetchedAt == Self.now)
        #expect(snapshot.isStale)
    }
}
