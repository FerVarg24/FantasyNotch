import Foundation
import Testing

@testable import SleeperKit
@testable import SleeperKitMocks

@Suite("Decodificación de modelos de Sleeper")
struct ModelDecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ fixture: String) throws -> T {
        try SleeperDecoder.decode(type, from: MockFixtures.data(named: fixture))
    }

    @Test("NFLState: semana y temporada de hoy")
    func nflState() throws {
        let state = try decode(NFLState.self, "state_nfl")
        #expect(state.seasonType == "regular")
        #expect(!state.season.isEmpty)
        #expect((1...22).contains(state.week))
    }

    @Test("SleeperUser: solo los campos del contrato")
    func user() throws {
        let user = try decode(SleeperUser.self, "user")
        #expect(user.userId == "900000000000000001")
        #expect(user.username == "manager_1")
    }

    @Test("League: ligas del usuario con campos opcionales ausentes")
    func leagues() throws {
        let leagues = try decode([League].self, "user_leagues")
        #expect(leagues.count == 5)
        #expect(leagues.allSatisfy { !$0.leagueId.isEmpty && !$0.name.isEmpty })
        #expect(leagues.first?.avatar == nil)
    }

    @Test("LeagueUser: nombre de equipo en metadata")
    func leagueUsers() throws {
        let users = try decode([LeagueUser].self, "league_users")
        #expect(users.count == 14)
        #expect(users.first?.metadata?.teamName == "Equipo 1")
    }

    @Test("Roster: dueño y titulares")
    func rosters() throws {
        let rosters = try decode([Roster].self, "rosters")
        #expect(rosters.count == 12)
        #expect(rosters.allSatisfy { !($0.starters ?? []).isEmpty })
    }

    @Test("Matchup final: puntos por titular alineados con los slots")
    func finalMatchups() throws {
        let matchups = try decode([Matchup].self, "matchups_week1_final")
        #expect(matchups.count == 12)
        for matchup in matchups {
            #expect(matchup.startersPoints.count == matchup.starters.count)
            #expect(abs(matchup.startersPoints.reduce(0, +) - matchup.points) < 0.011)
        }
        let pairs = Dictionary(grouping: matchups, by: \.matchupId)
        #expect(pairs.values.allSatisfy { $0.count == 2 })
    }

    @Test("Matchup con bye: matchup_id nulo y slot vacío \"0\"")
    func byeWeek() throws {
        let matchups = try decode([Matchup].self, "matchups_week14_bye")
        let byes = matchups.filter { $0.matchupId == nil }
        #expect(byes.count == 4)
        #expect(matchups.contains { $0.starters.contains("0") })
    }

    @Test("Matchup de una semana sin datos es un arreglo vacío")
    func emptyWeek() throws {
        #expect(try decode([Matchup].self, "matchups_week18_empty").isEmpty)
    }

    @Test("Matchup en vivo (derivado): menos puntos que el final y titulares en 0")
    func liveDerived() throws {
        let live = try decode([Matchup].self, "matchups_week1_live_DERIVED")
        let final = try decode([Matchup].self, "matchups_week1_final")
        #expect(live.count == final.count)
        #expect(zip(live, final).allSatisfy { $0.points <= $1.points })
        #expect(live.contains { $0.startersPoints.contains(0) && $0.points > 0 })
    }

    @Test("Player: DEF sin nombre completo y jugadores por ID")
    func players() throws {
        let players = try decode([String: Player].self, "players_subset")
        #expect(players.count == 240)
        #expect(players.values.contains { $0.position == "DEF" })
        #expect(players.values.allSatisfy { $0.playerId == $0.playerId.trimmingCharacters(in: .whitespaces) })
    }

    @Test("JSON inválido produce un error tipado, sin crash")
    func invalidJSON() throws {
        let data = try MockFixtures.data(named: "matchups_invalid")
        #expect {
            try SleeperDecoder.decode([Matchup].self, from: data)
        } throws: { error in
            guard case SleeperAPIError.decoding = error else { return false }
            return true
        }
    }

    @Test("MockSleeperAPI sirve los fixtures por escenario")
    func mockServesFixtures() async throws {
        let live = try await MockSleeperAPI(scenario: .live).matchups(leagueId: "x", week: 1)
        #expect(live.count == 12)
        let bye = try await MockSleeperAPI(scenario: .bye).matchups(leagueId: "x", week: 14)
        #expect(bye.contains { $0.matchupId == nil })
        let state = try await MockSleeperAPI().nflState()
        #expect(state.seasonType == "regular")
    }

    @Test("MockSleeperAPI con JSON inválido lanza SleeperAPIError.decoding")
    func mockInvalidScenario() async {
        await #expect {
            try await MockSleeperAPI(scenario: .invalid).matchups(leagueId: "x", week: 1)
        } throws: { error in
            guard case SleeperAPIError.decoding = error else { return false }
            return true
        }
    }

    @Test("Previews de MatchupSnapshot cubren en vivo, bye y desactualizado")
    func snapshotPreviews() {
        #expect(MatchupSnapshot.previewLive.opponent != nil)
        #expect(MatchupSnapshot.previewLive.me.starters.contains { $0.status == .playing })
        #expect(MatchupSnapshot.previewBye.opponent == nil)
        #expect(MatchupSnapshot.previewStale.isStale)
        #expect(!MatchupSnapshot.previewLive.isStale)
    }
}
