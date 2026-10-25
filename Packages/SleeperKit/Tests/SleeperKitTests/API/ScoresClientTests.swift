import Foundation
import Testing

@testable import SleeperKit

/// JSON con la forma real de `https://api.sleeper.com/scores/nfl/regular/2026/7` (grabado el 2026-10-24, partido
/// en estado `pre_game`), recortado a un partido pero conservando campos que el cliente no usa para probar que se ignoran.
let recordedScoresJSON = """
    [{
      "date": "2026-10-25", "game_id": "202610701", "last_updated": 1792800000000, "provider_week": "7",
      "season": "2026", "season_type": "regular", "sport": "nfl", "start_time": 1792958700000,
      "status": "pre_game", "total_views": 0, "updated_at": 1792800000000, "week": 7,
      "reactions": {"fire": 3},
      "metadata": {
        "away_record": "3-3", "away_team": "DEN", "home_record": "2-4", "home_team": "ARI",
        "canceled": false, "has_started": false, "is_in_progress": false, "is_over": false,
        "quarter": "", "quarter_num": "", "date_time": "2026-10-25T20:05:00+00:00",
        "stadium_details": {"name": "State Farm Stadium", "capacity": 63400}, "spread": "-2.5"
      }
    }]
    """

@Suite("ScoresClient")
struct ScoresClientTests {
    private func client(
        recorder: RequestRecorder = RequestRecorder(),
        status: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data(recordedScoresJSON.utf8)
    ) -> ScoresClient {
        ScoresClient(
            session: StubURLProtocol.session { request in
                recorder.record(request)
                return stubResponse(for: request, status: status, headers: headers, body: body)
            })
    }

    @Test("Pide /scores/nfl/regular/{season}/{week} en api.sleeper.com por GET con timeout de 10 s")
    func requestShape() async throws {
        let recorder = RequestRecorder()
        let games = try await client(recorder: recorder).games(season: "2026", week: 7)
        let request = try #require(recorder.requests.first)
        #expect(request.url?.absoluteString == "https://api.sleeper.com/scores/nfl/regular/2026/7")
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 10)
        #expect(games.count == 1)
    }

    @Test("Decodifica solo los campos usados y tolera el resto del objeto")
    func decodesUsedFieldsOnly() async throws {
        let game = try #require(try await client().games(season: "2026", week: 7).first)
        #expect(game.gameId == "202610701")
        #expect(game.status == "pre_game")
        #expect(game.startTime == 1_792_958_700_000)
        #expect(game.metadata?.homeTeam == "ARI")
        #expect(game.metadata?.awayTeam == "DEN")
        #expect(game.metadata?.isInProgress == false)
        #expect(game.metadata?.isOver == false)
        #expect(game.metadata?.hasStarted == false)
        #expect(game.metadata?.canceled == false)
    }

    @Test("Todos los campos son opcionales: un partido vacío decodifica")
    func emptyGameDecodes() async throws {
        let games = try await client(body: Data("[{}]".utf8)).games(season: "2026", week: 7)
        #expect(games.count == 1)
        #expect(games.first?.metadata == nil)
    }

    @Test("Si el endpoint no documentado cambia de forma → decoding, sin crash")
    func shapeChangeIsATypedError() async {
        await #expect {
            try await client(body: Data(#"{"games": []}"#.utf8)).games(season: "2026", week: 7)
        } throws: { error in
            guard case SleeperAPIError.decoding = error else { return false }
            return true
        }
    }

    @Test("404 → notFound, 429 → rateLimited, 5xx → server, 403 → badStatus")
    func statusMapping() async {
        await #expect(throws: SleeperAPIError.notFound) { try await client(status: 404).games(season: "2026", week: 7) }
        await #expect(throws: SleeperAPIError.rateLimited) { try await client(status: 429).games(season: "2026", week: 7) }
        await #expect(throws: SleeperAPIError.server(status: 503)) {
            try await client(status: 503).games(season: "2026", week: 7)
        }
        await #expect(throws: SleeperAPIError.badStatus(403)) { try await client(status: 403).games(season: "2026", week: 7) }
    }

    @Test("Una redirección no se sigue: se reporta como badStatus")
    func redirectsAreNotFollowed() async {
        await #expect(throws: SleeperAPIError.badStatus(302)) {
            try await client(status: 302, headers: ["Location": "https://evil.example/x"]).games(season: "2026", week: 7)
        }
    }

    @Test("Una respuesta de otro host se rechaza, incluido api.sleeper.app (otro cliente, otra lista)")
    func foreignHostResponse() async {
        for host in ["evil.example", "api.sleeper.app"] {
            let session = StubURLProtocol.session { request in
                stubResponse(for: request, url: URL(string: "https://\(host)/scores/nfl/regular/2026/7")!, body: Data("[]".utf8))
            }
            await #expect {
                try await ScoresClient(session: session).games(season: "2026", week: 7)
            } throws: { error in
                guard case SleeperAPIError.invalidRequest = error else { return false }
                return true
            }
        }
    }

    @Test("Una respuesta por http plano se rechaza")
    func plainHTTPResponse() async {
        let session = StubURLProtocol.session { request in
            stubResponse(for: request, url: URL(string: "http://api.sleeper.com/scores/nfl/regular/2026/7")!, body: Data("[]".utf8))
        }
        await #expect {
            try await ScoresClient(session: session).games(season: "2026", week: 7)
        } throws: { error in
            guard case SleeperAPIError.invalidRequest = error else { return false }
            return true
        }
    }

    @Test("Temporada o semana inválidas no generan ninguna petición", arguments: ["", "20/26", "..", "a b", "x?y=1"])
    func invalidSeason(value: String) async {
        let recorder = RequestRecorder()
        let scores = client(recorder: recorder)
        await #expect {
            try await scores.games(season: value, week: 7)
        } throws: { error in
            guard case SleeperAPIError.invalidRequest = error else { return false }
            return true
        }
        #expect(recorder.requests.isEmpty)
    }

    @Test("Semana fuera de rango no genera ninguna petición", arguments: [-1, 31])
    func invalidWeek(week: Int) async {
        let recorder = RequestRecorder()
        let scores = client(recorder: recorder)
        await #expect {
            try await scores.games(season: "2026", week: week)
        } throws: { error in
            guard case SleeperAPIError.invalidRequest = error else { return false }
            return true
        }
        #expect(recorder.requests.isEmpty)
    }

    @Test("Cuerpo mayor que 20 MB → responseTooLarge")
    func bodyTooLarge() async {
        await #expect(throws: SleeperAPIError.responseTooLarge) {
            try await client(body: Data(count: 20 * 1024 * 1024 + 1)).games(season: "2026", week: 7)
        }
    }

    @Test("Un fallo de red se convierte en SleeperAPIError.network")
    func networkFailure() async {
        let session = StubURLProtocol.session { _ in throw URLError(.timedOut) }
        await #expect {
            try await ScoresClient(session: session).games(season: "2026", week: 7)
        } throws: { error in
            guard case SleeperAPIError.network = error else { return false }
            return true
        }
    }

    @Test("El cliente de Sleeper v1 sigue limitado a su host: no acepta api.sleeper.com")
    func liveClientHostIsUnchanged() async {
        let session = StubURLProtocol.session { request in
            stubResponse(for: request, url: URL(string: "https://api.sleeper.com/v1/state/nfl")!, body: Data("{}".utf8))
        }
        await #expect {
            try await LiveSleeperAPI(session: session).nflState()
        } throws: { error in
            guard case SleeperAPIError.invalidRequest = error else { return false }
            return true
        }
    }
}
